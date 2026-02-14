/// Extract clean JSON from a response that may have trailing characters
/// Miners often append null bytes, newlines, or other garbage after the JSON
pub fn extract_clean_json(response: &str) -> Option<String> {
    // Remove leading/trailing whitespace and null bytes
    let trimmed = response.trim_matches(|c: char| c.is_whitespace() || c == '\0');
    
    // Find the last closing brace - that's where the JSON should end
    if let Some(last_brace) = trimmed.rfind('}') {
        let json_str = &trimmed[..=last_brace];
        
        // Basic validation: should start with '{'
        if json_str.starts_with('{') {
            return Some(json_str.to_string());
        }
    }
    
    // If we can't find valid JSON boundaries, we return None
    // This allows the caller to decide whether to use the original string or fail
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_clean_json_valid() {
        let json = r#"{"status":"S"}"#;
        assert_eq!(extract_clean_json(json), Some(json.to_string()));
    }

    #[test]
    fn test_extract_clean_json_trailing_garbage() {
        let json = r#"{"status":"S"} garbage"#;
        assert_eq!(extract_clean_json(json), Some(r#"{"status":"S"}"#.to_string()));
    }

    #[test]
    fn test_extract_clean_json_null_bytes() {
        let json = "{\"status\":\"S\"}\0\0";
        assert_eq!(extract_clean_json(json), Some(r#"{"status":"S"}"#.to_string()));
    }

    #[test]
    fn test_extract_clean_json_invalid() {
        let json = "not json";
        assert_eq!(extract_clean_json(json), None);
    }
    
    #[test]
    fn test_extract_clean_json_no_braces() {
         let json = "  \0  ";
         assert_eq!(extract_clean_json(json), None);
    }
}
