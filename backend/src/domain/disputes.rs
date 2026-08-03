use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum DisputeStatus {
    Open,
    Resolved,
    Dismissed,
}

impl DisputeStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            DisputeStatus::Open => "open",
            DisputeStatus::Resolved => "resolved",
            DisputeStatus::Dismissed => "dismissed",
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct MatchDispute {
    pub id: Uuid,
    pub match_record_id: Uuid,
    pub raised_by: Uuid,
    pub reason: String,
    pub status: DisputeStatus,
    pub counter_screenshot_url: Option<String>,
    pub resolved_by: Option<Uuid>,
    pub resolution_notes: Option<String>,
}

pub fn raise_match_dispute(
    match_record_id: Uuid,
    raised_by: Uuid,
    reason: String,
    counter_screenshot_url: Option<String>,
) -> MatchDispute {
    MatchDispute {
        id: Uuid::new_v4(),
        match_record_id,
        raised_by,
        reason,
        status: DisputeStatus::Open,
        counter_screenshot_url,
        resolved_by: None,
        resolution_notes: None,
    }
}

pub fn resolve_dispute(
    mut dispute: MatchDispute,
    dismiss: bool,
    resolved_by: Uuid,
    notes: Option<String>,
) -> MatchDispute {
    dispute.status = if dismiss {
        DisputeStatus::Dismissed
    } else {
        DisputeStatus::Resolved
    };
    dispute.resolved_by = Some(resolved_by);
    dispute.resolution_notes = notes;
    dispute
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dispute_lifecycle() {
        let dispute = raise_match_dispute(Uuid::new_v4(), Uuid::new_v4(), "Incorrect score".into(), None);
        assert_eq!(dispute.status, DisputeStatus::Open);

        let resolved = resolve_dispute(dispute, false, Uuid::new_v4(), Some("Fixed".into()));
        assert_eq!(resolved.status, DisputeStatus::Resolved);
        assert!(resolved.resolved_by.is_some());
    }
}

