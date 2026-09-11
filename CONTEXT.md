# Claudey

Claudey is a desktop companion that makes coding-agent activity visible through a small, expressive character.

## Language

**Claudey**:
The original pixel-art companion that lives above desktop windows and responds playfully to interaction. He has no feeding, care, or progression requirements.
_Avoid_: Pet game

**Working**:
A coding agent is handling a user's request.
_Avoid_: Thinking (which suggests only internal reasoning)

**Finished**:
A coding agent has finished responding; this does not establish that the user's task succeeded.
_Avoid_: Success

**Needs you**:
A coding agent is waiting for a user decision or answer.
_Avoid_: Error

**Session**:
A distinct coding-agent conversation whose activity contributes to Claudey's displayed state.
_Avoid_: Terminal (multiple conversations can use the same terminal application)

**Ready**:
A session's agent has stopped responding and waits for input; Herdr reports it as idle or done. Becoming ready after working is what makes a response finished.
_Avoid_: Done (Herdr's word for an unseen ready state)

**Uncertain**:
An agent is present but Herdr cannot classify what it is doing. Uncertain never implies finished.
_Avoid_: Unknown (Herdr's wire value)
