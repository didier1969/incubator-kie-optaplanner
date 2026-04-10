// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::nco::TensorData;
use dfdx::prelude::*;

// Define a Hybrid Neural Network architecture.
// We use CPU-based Message Passing (Graph Convolution) to aggregate neighborhood features,
// followed by a Multi-Layer Perceptron (MLP) in dfdx to process the combined node+neighborhood state.
// Input Dimension:
// 9 (Job Features) + 9 (Job-to-Job Aggregation) + 29 (Job-to-Resource Aggregation) + 17 (Global Features) = 64
pub type NcoBrain = (
    Linear<64, 64>,
    ReLU,
    Linear<64, 32>,
    ReLU,
    Linear<32, 1>,
    Sigmoid, // Output a branching probability [0, 1]
);

#[derive(Debug)]
pub struct NcoInferenceEngine {
    dev: Cpu,
    model: <NcoBrain as BuildOnDevice<Cpu, f32>>::Built,
}

impl Default for NcoInferenceEngine {
    fn default() -> Self {
        let dev = Cpu::default();
        let model = dev.build_module::<NcoBrain, f32>();
        Self { dev, model }
    }
}

impl NcoInferenceEngine {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Runs a forward pass on the extracted TensorData.
    /// Incorporates Bipartite Graph Message Passing and Global State Concatenation.
    pub fn forward_pass(&self, tensor_data: &TensorData) -> Vec<f32> {
        let num_jobs = tensor_data.job_features.len();
        let num_resources = tensor_data.resource_features.len();
        
        if num_jobs == 0 {
            return vec![];
        }

        // 1. CPU-based Graph Convolution: Job-to-Job Message Passing
        let mut job_aggregated_features = vec![vec![0.0f32; 9]; num_jobs];
        let mut job_in_degrees = vec![0.0f32; num_jobs];

        for i in 0..tensor_data.job_to_job_edge_src.len() {
            let src = tensor_data.job_to_job_edge_src[i];
            let dst = tensor_data.job_to_job_edge_dst[i];
            
            job_in_degrees[dst] += 1.0;
            for (feat_idx, &val) in tensor_data.job_features[src].iter().enumerate() {
                if feat_idx < 9 {
                    job_aggregated_features[dst][feat_idx] += val;
                }
            }
        }

        for i in 0..num_jobs {
            if job_in_degrees[i] > 0.0 {
                for feat_idx in 0..9 {
                    job_aggregated_features[i][feat_idx] /= job_in_degrees[i];
                }
            }
        }

        // 2. CPU-based Bipartite Graph Convolution: Resource-to-Job Message Passing
        // (A job needs to know the state of the machines it requires)
        let mut resource_aggregated_features = vec![vec![0.0f32; 29]; num_jobs];
        let mut res_in_degrees = vec![0.0f32; num_jobs];

        for i in 0..tensor_data.job_to_resource_edge_src.len() {
            let job_idx = tensor_data.job_to_resource_edge_src[i];
            let res_idx = tensor_data.job_to_resource_edge_dst[i];
            
            res_in_degrees[job_idx] += 1.0;
            if res_idx < num_resources {
                for (feat_idx, &val) in tensor_data.resource_features[res_idx].iter().enumerate() {
                    if feat_idx < 29 {
                        resource_aggregated_features[job_idx][feat_idx] += val;
                    }
                }
            }
        }

        for i in 0..num_jobs {
            if res_in_degrees[i] > 0.0 {
                for feat_idx in 0..29 {
                    resource_aggregated_features[i][feat_idx] /= res_in_degrees[i];
                }
            }
        }

        // 3. Flatten job features (Original 9 + Job-Agg 9 + Res-Agg 29 + Global 17 = 64)
        let mut flattened_features = Vec::with_capacity(num_jobs * 64);
        for i in 0..num_jobs {
            // A. Original Job Features (9)
            flattened_features.extend_from_slice(&tensor_data.job_features[i]);
            while flattened_features.len() % 64 < 9 { flattened_features.push(0.0); }
            
            // B. Job-to-Job Neighborhood (9)
            flattened_features.extend_from_slice(&job_aggregated_features[i]);
            while flattened_features.len() % 64 < 18 { flattened_features.push(0.0); }
            
            // C. Resource Availability/Occupancy (29)
            flattened_features.extend_from_slice(&resource_aggregated_features[i]);
            while flattened_features.len() % 64 < 47 { flattened_features.push(0.0); }
            
            // D. Global Factory State (17)
            flattened_features.extend_from_slice(&tensor_data.global_features);
            while flattened_features.len() % 64 != 0 { flattened_features.push(0.0); }
        }

        // 4. Create the input tensor using Const for the inner dimension
        let input_tensor = self.dev.tensor_from_vec(
            flattened_features,
            (num_jobs, dfdx::shapes::Const::<64>),
        );

        // 5. Execute the forward pass through the SOTA Bipartite NcoBrain
        let output_tensor = self.model.forward(input_tensor);

        // 6. Extract the probabilities back into a standard Rust Vec
        let probabilities = output_tensor.as_vec();
        
        probabilities
    }
}
