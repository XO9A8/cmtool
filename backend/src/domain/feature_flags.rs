//! # Feature Flag System
//!
//! Provides a runtime-toggleable feature flag map stored in `AppState`.
//! Allows admins to disable expensive optional features (AI Insights, Live Standings)
//! without releasing app updates — guaranteeing core match upload always works.

use serde::{Deserialize, Serialize};

/// Runtime-configurable feature flags.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeatureFlags {
    /// When `false`, switches Gemini API calls to the deterministic Rust fallback engine.
    pub enable_ai_insights: bool,
    /// When `false`, leaderboard returns a cached snapshot instead of a live DB query.
    pub enable_live_standings: bool,
}

impl Default for FeatureFlags {
    fn default() -> Self {
        Self {
            enable_ai_insights: true,
            enable_live_standings: true,
        }
    }
}

/// Request payload for the admin feature-flag toggle endpoint.
#[derive(Debug, Deserialize)]
pub struct UpdateFlagsRequest {
    pub enable_ai_insights: Option<bool>,
    pub enable_live_standings: Option<bool>,
}

impl FeatureFlags {
    /// Applies a partial update from an `UpdateFlagsRequest`, leaving unset fields unchanged.
    pub fn apply_update(&mut self, req: UpdateFlagsRequest) {
        if let Some(v) = req.enable_ai_insights {
            self.enable_ai_insights = v;
        }
        if let Some(v) = req.enable_live_standings {
            self.enable_live_standings = v;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_flags_enabled() {
        let flags = FeatureFlags::default();
        assert!(flags.enable_ai_insights);
        assert!(flags.enable_live_standings);
    }

    #[test]
    fn test_partial_flag_update() {
        let mut flags = FeatureFlags::default();
        flags.apply_update(UpdateFlagsRequest {
            enable_ai_insights: Some(false),
            enable_live_standings: None,
        });
        assert!(!flags.enable_ai_insights);
        assert!(flags.enable_live_standings); // unchanged
    }
}
