# Make the action a varchar rather than an enum
ALTER TABLE statistics CHANGE action action VARCHAR( 255 ) NULL DEFAULT NULL;

# Fix the missing SESSION_DELETED statuses
UPDATE statistics SET action = 'SESSION_DELETED' WHERE action = "";
