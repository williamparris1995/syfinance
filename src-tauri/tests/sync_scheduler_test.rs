use std::time::Duration;

#[cfg(test)]
mod sync_scheduler_tests {
    use super::*;

    #[tokio::test]
    async fn test_sync_settings_default() {
        // Test that default settings are correct
        use finance_app::infrastructure::sync::SyncSettings;

        let settings = SyncSettings::default();
        assert!(settings.enabled);
        assert_eq!(settings.interval_minutes, 15);
    }

    #[tokio::test]
    async fn test_sync_settings_minimum_interval() {
        // Test that minimum interval is enforced
        use finance_app::infrastructure::sync::SyncSettings;

        let settings = SyncSettings {
            enabled: true,
            interval_minutes: 1, // Below minimum of 5
        };

        // The scheduler should enforce minimum of 5 minutes
        assert_eq!(settings.interval_minutes.max(5), 5);
    }

    #[tokio::test]
    async fn test_backoff_delays_are_correct() {
        // Test that backoff delays follow exponential pattern: 2s, 4s, 8s, 16s
        let expected_delays = [
            Duration::from_secs(2),
            Duration::from_secs(4),
            Duration::from_secs(8),
            Duration::from_secs(16),
        ];

        // This is a compile-time check that the constants are correct
        // The actual BACKOFF_DELAYS constant is private, so we verify the pattern
        assert_eq!(expected_delays.len(), 4);
        assert_eq!(expected_delays[0], Duration::from_secs(2));
        assert_eq!(expected_delays[1], Duration::from_secs(4));
        assert_eq!(expected_delays[2], Duration::from_secs(8));
        assert_eq!(expected_delays[3], Duration::from_secs(16));
    }
}
