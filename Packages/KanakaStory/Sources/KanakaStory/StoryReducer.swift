public enum StoryReducer {
    public static func applying(
        _ envelope: StoryEvidenceEnvelope,
        to originalState: StoryState,
        using rules: StoryRuleSet
    ) -> (state: StoryState, decision: StoryTransitionDecision) {
        guard originalState.rulesID == rules.id,
              originalState.rulesRevision == rules.revision,
              envelope.rulesRevision == rules.revision else {
            let error = StoryTransitionError.rulesMismatch(
                expectedID: originalState.rulesID,
                expectedRevision: originalState.rulesRevision,
                actualID: rules.id,
                actualRevision: envelope.rulesRevision
            )
            return rejected(error, envelope: envelope, state: originalState)
        }

        if let accepted = originalState.acceptedEvidence.first(where: {
            $0.occurrenceID == envelope.occurrenceID
        }) {
            guard accepted == envelope else {
                return rejected(
                    .evidenceIdentityCollision(envelope.occurrenceID),
                    envelope: envelope,
                    state: originalState
                )
            }
            let audit = StoryAuditRecord(
                occurrenceID: envelope.occurrenceID,
                evidenceID: envelope.evidenceID,
                accepted: true,
                newlyAchievedMilestones: [],
                rejection: nil
            )
            return (originalState, .alreadyApplied(audit: audit))
        }

        guard let actualRule = rules.orderedEvidence.first(where: {
            $0.evidenceID == envelope.evidenceID
        }) else {
            return rejected(.unknownEvidence(envelope.evidenceID), envelope: envelope, state: originalState)
        }
        guard actualRule.sourceKind == envelope.source.kind else {
            return rejected(
                .forbiddenEvidenceSource(expected: actualRule.sourceKind, actual: envelope.source.kind),
                envelope: envelope,
                state: originalState
            )
        }
        guard originalState.acceptedEvidence.count < rules.orderedEvidence.count else {
            return rejected(.unknownEvidence(envelope.evidenceID), envelope: envelope, state: originalState)
        }

        let expected = rules.orderedEvidence[originalState.acceptedEvidence.count]
        guard expected.evidenceID == envelope.evidenceID else {
            return rejected(
                .evidenceOutOfSequence(expected: expected.evidenceID, actual: envelope.evidenceID),
                envelope: envelope,
                state: originalState
            )
        }

        if let milestone = expected.achievesMilestone,
           let prerequisite = milestone.prerequisite,
           !originalState.hasAchieved(prerequisite) {
            return rejected(
                .missingPrerequisite(target: milestone, required: prerequisite),
                envelope: envelope,
                state: originalState
            )
        }

        var state = originalState
        state.acceptedEvidence.append(envelope)
        var newlyAchieved: [StoryMilestoneID] = []
        if let milestone = expected.achievesMilestone, !state.hasAchieved(milestone) {
            state.achievements.append(StoryMilestoneAchievement(
                milestone: milestone,
                achievedAt: envelope.occurredAt,
                evidenceOccurrenceID: envelope.occurrenceID,
                rulesRevision: rules.revision
            ))
            newlyAchieved.append(milestone)
        }

        let audit = StoryAuditRecord(
            occurrenceID: envelope.occurrenceID,
            evidenceID: envelope.evidenceID,
            accepted: true,
            newlyAchievedMilestones: newlyAchieved,
            rejection: nil
        )
        return (state, .applied(newlyAchieved: newlyAchieved, audit: audit))
    }

    private static func rejected(
        _ error: StoryTransitionError,
        envelope: StoryEvidenceEnvelope,
        state: StoryState
    ) -> (state: StoryState, decision: StoryTransitionDecision) {
        let audit = StoryAuditRecord(
            occurrenceID: envelope.occurrenceID,
            evidenceID: envelope.evidenceID,
            accepted: false,
            newlyAchievedMilestones: [],
            rejection: error
        )
        return (state, .rejected(error, audit: audit))
    }
}
