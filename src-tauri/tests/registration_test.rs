#[cfg(test)]
mod registration_tests {
    use reqwest;
    use serde_json::Value;

    const API_BASE_URL: &str = "http://127.0.0.1:3000";

    #[tokio::test]
    async fn test_register_endpoint_returns_ids() {
        let client = reqwest::Client::new();
        let response = client
            .post(format!("{}/api/register", API_BASE_URL))
            .send()
            .await;

        // If server is not running, skip test
        if response.is_err() {
            println!("Skipping test - server not running");
            return;
        }

        let response = response.unwrap();
        assert_eq!(response.status(), 200);

        let body: Value = response.json().await.unwrap();
        
        // Verify response has account_id and device_id
        assert!(body.get("account_id").is_some());
        assert!(body.get("device_id").is_some());

        let account_id = body["account_id"].as_str().unwrap();
        let device_id = body["device_id"].as_str().unwrap();

        // Verify they are valid UUIDs (36 characters with hyphens)
        assert_eq!(account_id.len(), 36);
        assert_eq!(device_id.len(), 36);
        assert!(account_id.contains('-'));
        assert!(device_id.contains('-'));
    }

    #[tokio::test]
    async fn test_register_generates_unique_ids() {
        let client = reqwest::Client::new();
        
        // First registration
        let response1 = client
            .post(format!("{}/api/register", API_BASE_URL))
            .send()
            .await;

        if response1.is_err() {
            println!("Skipping test - server not running");
            return;
        }

        let body1: Value = response1.unwrap().json().await.unwrap();
        let account_id1 = body1["account_id"].as_str().unwrap();
        let device_id1 = body1["device_id"].as_str().unwrap();

        // Second registration
        let response2 = client
            .post(format!("{}/api/register", API_BASE_URL))
            .send()
            .await
            .unwrap();

        let body2: Value = response2.json().await.unwrap();
        let account_id2 = body2["account_id"].as_str().unwrap();
        let device_id2 = body2["device_id"].as_str().unwrap();

        // Verify all IDs are unique
        assert_ne!(account_id1, account_id2);
        assert_ne!(device_id1, device_id2);
        assert_ne!(account_id1, device_id1);
        assert_ne!(account_id2, device_id2);
    }
}
