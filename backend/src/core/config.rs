use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use directories::ProjectDirs;

/// Configuration for miner authentication and connection settings
#[derive(Debug, Clone, Serialize, Deserialize)]
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub antminer_credentials: MinerCredentials,
    pub whatsminer_credentials: MinerCredentials,
    pub scan_thread_count: u32,
    pub monitor_interval: u64,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            antminer_credentials: MinerCredentials::default(), // root/root
            whatsminer_credentials: MinerCredentials::new("admin".to_string(), "admin".to_string()),
            scan_thread_count: 32,
            monitor_interval: 30,
        }
    }
}

impl AppSettings {
    pub fn load() -> Self {
        if let Some(config_path) = Self::get_config_path() {
            if config_path.exists() {
                if let Ok(content) = fs::read_to_string(&config_path) {
                    if let Ok(settings) = serde_json::from_str(&content) {
                        return settings;
                    }
                }
            }
        }
        Self::default()
    }

    pub fn save(&self) -> Result<(), String> {
        if let Some(config_path) = Self::get_config_path() {
            if let Some(parent) = config_path.parent() {
                fs::create_dir_all(parent).map_err(|e| e.to_string())?;
            }
            let content = serde_json::to_string_pretty(self).map_err(|e| e.to_string())?;
            fs::write(config_path, content).map_err(|e| e.to_string())?;
            Ok(())
        } else {
            Err("Could not determine config path".to_string())
        }
    }

    fn get_config_path() -> Option<PathBuf> {
        ProjectDirs::from("com", "example", "miner-manager")
            .map(|proj_dirs| proj_dirs.config_dir().join("app_settings.json"))
    }
}
