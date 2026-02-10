/// Configuration for miner authentication and connection settings
#[derive(Debug, Clone)]
pub struct MinerCredentials {
    pub username: String,
    pub password: String,
}

impl Default for MinerCredentials {
    fn default() -> Self {
        Self {
            username: "root".to_string(),
            password: "root".to_string(),
        }
    }
}

impl MinerCredentials {
    pub fn new(username: String, password: String) -> Self {
        Self { username, password }
    }
}
