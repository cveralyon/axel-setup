# Remove AI Code Slop

Check the diff against main and remove all AI-generated slop introduced in this branch.

This includes:
- Extra comments that a human wouldn't add or that are inconsistent with the rest of the file
- Extra defensive checks or try/catch blocks abnormal for that area (especially if called by trusted/validated codepaths)
- Casts to `any` to get around type issues
- Unnecessary abstractions or over-engineering for simple operations
- Redundant type annotations on obvious types
- Verbose error handling for impossible scenarios

Report at the end with only a 1-3 sentence summary of what you changed.
