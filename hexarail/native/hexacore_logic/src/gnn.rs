// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::nco::TensorData;
use dfdx::prelude::*;

// Define a Hybrid Neural Network architecture.
// We use CPU-based Message Passing (Graph Convolution) to aggregate neighborhood features,
// followed by a Multi-Layer Perceptron (MLP) in dfdx to process the combined node+neighborhood state.
pub type NcoBrain = (
    Linear<18, 32>, // 9 original features + 9 aggregated neighborhood features
    ReLU,
    Linear<32, 16>,
    ReLU,
    Linear<16, 1>,
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
    /// Incorporates a single iteration of Graph Message Passing.
    pub fn forward_pass(&self, tensor_data: &TensorData) -> Vec<f32> {
        let num_jobs = tensor_data.job_features.len();
        if num_jobs == 0 {
            return vec![];
        }

        // 1. CPU-based Graph Convolution (Message Passing)
        // For each node, we aggregate the features of its incoming neighbors.
        let mut aggregated_features = vec![vec![0.0f32; 9]; num_jobs];
        let mut in_degrees = vec![0.0f32; num_jobs];

        for i in 0..tensor_data.job_to_job_edge_src.len() {
            let src = tensor_data.job_to_job_edge_src[i];
            let dst = tensor_data.job_to_job_edge_dst[i];
            
            in_degrees[dst] += 1.0;
            for (feat_idx, &val) in tensor_data.job_features[src].iter().enumerate() {
                if feat_idx < 9 {
                    aggregated_features[dst][feat_idx] += val;
                }
            }
        }

        // Mean aggregation
        for i in 0..num_jobs {
            if in_degrees[i] > 0.0 {
                for feat_idx in 0..9 {
                    aggregated_features[i][feat_idx] /= in_degrees[i];
                }
            }
        }

        // 2. Flatten job features (Original 9 + Aggregated 9 = 18) into a 1D vector
        let mut flattened_features = Vec::with_capacity(num_jobs * 18);
        for i in 0..num_jobs {
            flattened_features.extend_from_slice(&tensor_data.job_features[i]);
            // Pad to 9 if necessary
            while flattened_features.len() % 9 != 0 {
                flattened_features.push(0.0);
            }
            flattened_features.extend_from_slice(&aggregated_features[i]);
        }

        // 3. Create the input tensor using Const for the inner dimension
        let input_tensor = self.dev.tensor_from_vec(
            flattened_features,
            (num_jobs, dfdx::shapes::Const::<18>),
        );

        // 4. Execute the forward pass through the NcoBrain
        let output_tensor = self.model.forward(input_tensor);

        // 5. Extract the probabilities back into a standard Rust Vec
        let probabilities = output_tensor.as_vec();
        
        probabilities
    }
}
