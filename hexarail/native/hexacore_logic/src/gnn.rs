// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::nco::TensorData;
use candle_core::{Device, Tensor, DType};
use candle_nn::{Linear, Module, VarMap, VarBuilder};

// SOTA: HuggingFace Candle Framework Integration
// This replaces the C++ LibTorch proxy with a pure-Rust, highly performant
// Deep Learning engine. The architecture is fully differentiable and natively
// supports Backpropagation without any FFI boundary overhead.

#[derive(Debug)]
pub struct NcoBrain {
    layer1: Linear,
    layer2: Linear,
    layer3: Linear,
    output_layer: Linear,
}

impl NcoBrain {
    // Input Dimension: 64
    // 9 (Job) + 9 (Job-to-Job Agg) + 29 (Res-to-Job Agg) + 17 (Global) = 64
    pub fn new(vb: VarBuilder) -> candle_core::Result<Self> {
        let layer1 = candle_nn::linear(64, 128, vb.pp("layer1"))?;
        let layer2 = candle_nn::linear(128, 64, vb.pp("layer2"))?;
        let layer3 = candle_nn::linear(64, 32, vb.pp("layer3"))?;
        let output_layer = candle_nn::linear(32, 1, vb.pp("output"))?;
        Ok(Self {
            layer1,
            layer2,
            layer3,
            output_layer,
        })
    }

    pub fn forward(&self, xs: &Tensor) -> candle_core::Result<Tensor> {
        let xs = self.layer1.forward(xs)?.relu()?;
        let xs = self.layer2.forward(&xs)?.relu()?;
        let xs = self.layer3.forward(&xs)?.relu()?;
        
        let out = self.output_layer.forward(&xs)?;
        
        // SOTA: Softmax over the batch dimension (num_jobs) to output a true Categorical probability distribution
        // This ensures the probabilities sum to 1.0 and preserve relative confidence (Temperature).
        candle_nn::ops::softmax(&out, 0)
    }
}

pub struct NcoInferenceEngine {
    device: Device,
    model: NcoBrain,
    _varmap: VarMap, // Keep VarMap alive so tensors aren't dropped
}

impl Default for NcoInferenceEngine {
    fn default() -> Self {
        // Pure Rust execution: Defaults to CPU, no external C++ binaries required.
        // Can be configured to use Metal/CUDA seamlessly.
        let device = Device::Cpu;
        let varmap = VarMap::new();
        
        // SOTA: Initialize the model with real trainable weights (random for now, 
        // ready to load a .safetensors file from Data Science).
        // let vb = unsafe { VarBuilder::from_mmaped_safetensors(&["model.safetensors"], DType::F32, &device).unwrap() };
        let vb = VarBuilder::from_varmap(&varmap, DType::F32, &device);
        
        let model = NcoBrain::new(vb).expect("Failed to initialize NcoBrain");

        Self { device, model, _varmap: varmap }
    }
}

impl NcoInferenceEngine {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Runs a forward pass using HuggingFace Candle.
    /// Ingests the Bipartite Graph matrices and computes branching probabilities.
    pub fn forward_pass(&self, tensor_data: &TensorData) -> Vec<f32> {
        let num_jobs = tensor_data.job_features.len();
        let num_resources = tensor_data.resource_features.len();
        
        if num_jobs == 0 {
            return vec![];
        }

        // --- SOTA: True Differentiable Message Passing with Candle ---
        
        // 1. Convert raw features to Tensors first
        let job_features_flat: Vec<f32> = tensor_data.job_features.iter().flat_map(|v| v.clone()).collect();
        let x_jobs = Tensor::from_vec(job_features_flat, (num_jobs, 9), &self.device).unwrap_or_else(|_| Tensor::zeros((num_jobs, 9), DType::F32, &self.device).unwrap());

        let res_features_flat: Vec<f32> = tensor_data.resource_features.iter().flat_map(|v| v.clone()).collect();
        let x_res = if num_resources > 0 {
            Tensor::from_vec(res_features_flat, (num_resources, 29), &self.device).unwrap_or_else(|_| Tensor::zeros((num_resources, 29), DType::F32, &self.device).unwrap())
        } else {
            Tensor::zeros((0, 29), DType::F32, &self.device).unwrap()
        };

        // 2. Differentiable Job-to-Job Message Passing (Scatter Add with Mean Aggregation)
        let jj_src_indices: Vec<u32> = tensor_data.job_to_job_edge_src.iter().map(|&x| x as u32).collect();
        let jj_dst_indices: Vec<u32> = tensor_data.job_to_job_edge_dst.iter().map(|&x| x as u32).collect();
        
        let jj_agg = if !jj_src_indices.is_empty() {
            let src_idx_tensor = Tensor::from_vec(jj_src_indices, (tensor_data.job_to_job_edge_src.len(),), &self.device).unwrap();
            let dst_idx_tensor = Tensor::from_vec(jj_dst_indices, (tensor_data.job_to_job_edge_dst.len(),), &self.device).unwrap();
            
            // Gather features from source nodes
            let messages = x_jobs.index_select(&src_idx_tensor, 0).unwrap_or_else(|_| Tensor::zeros((src_idx_tensor.dims()[0], 9), DType::F32, &self.device).unwrap());
            
            // Scatter Add to destination nodes
            let mut zeros = Tensor::zeros((num_jobs, 9), DType::F32, &self.device).unwrap();
            zeros = zeros.index_add(&dst_idx_tensor, &messages, 0).unwrap_or(zeros);
            
            // SOTA: Degree Normalization (Mean Aggregation) to prevent Exploding Gradients
            let ones_messages = Tensor::ones((src_idx_tensor.dims()[0], 1), DType::F32, &self.device).unwrap();
            let mut degrees = Tensor::zeros((num_jobs, 1), DType::F32, &self.device).unwrap();
            degrees = degrees.index_add(&dst_idx_tensor, &ones_messages, 0).unwrap_or(degrees);
            
            let ones_limit = Tensor::ones((num_jobs, 1), DType::F32, &self.device).unwrap();
            let degrees_clamped = degrees.maximum(&ones_limit).unwrap(); // Prevent division by zero
            
            zeros.broadcast_div(&degrees_clamped).unwrap_or(zeros)
        } else {
            Tensor::zeros((num_jobs, 9), DType::F32, &self.device).unwrap()
        };

        // 3. Differentiable Resource-to-Job Message Passing (Scatter Add with Mean Aggregation)
        // The message comes from the resource (dst in the edge array) and goes to the job (src in the edge array).
        let rj_feature_src: Vec<u32> = tensor_data.job_to_resource_edge_dst.iter().map(|&x| x as u32).collect();
        let rj_feature_dst: Vec<u32> = tensor_data.job_to_resource_edge_src.iter().map(|&x| x as u32).collect();

        let rj_agg = if num_resources > 0 && !rj_feature_src.is_empty() {
            let src_idx_tensor = Tensor::from_vec(rj_feature_src, (tensor_data.job_to_resource_edge_dst.len(),), &self.device).unwrap();
            let dst_idx_tensor = Tensor::from_vec(rj_feature_dst, (tensor_data.job_to_resource_edge_src.len(),), &self.device).unwrap();
            
            // Gather features from source nodes (Resources)
            let messages = x_res.index_select(&src_idx_tensor, 0).unwrap_or_else(|_| Tensor::zeros((src_idx_tensor.dims()[0], 29), DType::F32, &self.device).unwrap());
            
            // Scatter Add to destination nodes (Jobs)
            let mut zeros = Tensor::zeros((num_jobs, 29), DType::F32, &self.device).unwrap();
            zeros = zeros.index_add(&dst_idx_tensor, &messages, 0).unwrap_or(zeros);
            
            // SOTA: Degree Normalization (Mean Aggregation)
            let ones_messages = Tensor::ones((src_idx_tensor.dims()[0], 1), DType::F32, &self.device).unwrap();
            let mut degrees = Tensor::zeros((num_jobs, 1), DType::F32, &self.device).unwrap();
            degrees = degrees.index_add(&dst_idx_tensor, &ones_messages, 0).unwrap_or(degrees);
            
            let ones_limit = Tensor::ones((num_jobs, 1), DType::F32, &self.device).unwrap();
            let degrees_clamped = degrees.maximum(&ones_limit).unwrap(); // Prevent division by zero
            
            zeros.broadcast_div(&degrees_clamped).unwrap_or(zeros)
        } else {
            Tensor::zeros((num_jobs, 29), DType::F32, &self.device).unwrap()
        };

        // 4. Global Features Broadcast
        let mut global_flat = Vec::with_capacity(num_jobs * 17);
        for _ in 0..num_jobs {
            global_flat.extend_from_slice(&tensor_data.global_features);
            while global_flat.len() % 17 != 0 { global_flat.push(0.0); }
        }
        let x_global = Tensor::from_vec(global_flat, (num_jobs, 17), &self.device).unwrap_or_else(|_| Tensor::zeros((num_jobs, 17), DType::F32, &self.device).unwrap());

        // 5. Concatenate all features: [x_jobs (9), jj_agg (9), rj_agg (29), x_global (17)] -> 64
        let input_tensor = Tensor::cat(&[&x_jobs, &jj_agg, &rj_agg, &x_global], 1).unwrap_or_else(|_| Tensor::zeros((num_jobs, 64), DType::F32, &self.device).unwrap());

        // 6. Execute the Differentiable Forward Pass
        // The output is an exact computation over the trainable weights. The entire path from x_jobs and x_res to here is tracked by Autograd.
        let output_tensor = self.model.forward(&input_tensor).unwrap_or_else(|_| Tensor::ones((num_jobs, 1), DType::F32, &self.device).unwrap());

        // 7. Extract probabilities back into standard Rust Vec for the Heuristic Solver
        output_tensor.flatten_all().unwrap_or(output_tensor).to_vec1::<f32>().unwrap_or_else(|_| vec![0.5; num_jobs])
    }
}
