use thiserror::Error;

/// Errors that can occur when communicating with miners
#[derive(Debug, Error)]
pub enum MinerError {
    #[error("Connection timeout: {0}")]
    Timeout(String),
    
    #[error("Invalid JSON response: {0}")]
    ParseError(#[from] serde_json::Error),
    
    #[error("Network error: {0}")]
    NetworkError(#[from] std::io::Error),
    
    #[error("Unsupported miner model: {0}")]
    UnsupportedModel(String),
    
    #[error("Authentication failed")]
    AuthenticationError,
    
    #[error("Invalid response format")]
    InvalidResponse,
}

pub type Result<T> = std::result::Result<T, MinerError>;
