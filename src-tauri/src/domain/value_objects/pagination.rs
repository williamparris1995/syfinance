use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginationParams {
    pub first: u32,
    pub after: Option<String>,
    pub before: Option<String>,
}

impl Default for PaginationParams {
    fn default() -> Self {
        Self {
            first: 50,
            after: None,
            before: None,
        }
    }
}

impl PaginationParams {
    pub fn capped_first(&self) -> i64 {
        self.first.min(200) as i64
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PageInfo {
    pub has_next_page: bool,
    pub has_prev_page: bool,
    pub next_cursor: Option<String>,
    pub prev_cursor: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginatedResult<T> {
    pub items: Vec<T>,
    pub page_info: PageInfo,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SortCursor {
    pub keys: Vec<(String, String)>,
}

impl SortCursor {
    pub fn encode(&self) -> Result<String, String> {
        let json = serde_json::to_string(&self.keys)
            .map_err(|e| format!("Failed to serialize cursor: {}", e))?;
        Ok(BASE64.encode(json.as_bytes()))
    }

    pub fn decode(encoded: &str) -> Result<Self, String> {
        let bytes = BASE64
            .decode(encoded)
            .map_err(|e| format!("Invalid cursor encoding: {}", e))?;
        let keys: Vec<(String, String)> =
            serde_json::from_slice(&bytes).map_err(|e| format!("Invalid cursor format: {}", e))?;
        Ok(Self { keys })
    }

    pub fn get(&self, column: &str) -> Option<&str> {
        self.keys
            .iter()
            .find(|(k, _)| k == column)
            .map(|(_, v)| v.as_str())
    }
}

pub fn build_cursor(pairs: Vec<(&str, String)>) -> Option<String> {
    let cursor = SortCursor {
        keys: pairs.into_iter().map(|(k, v)| (k.to_string(), v)).collect(),
    };
    cursor.encode().ok()
}
