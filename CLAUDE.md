# MoneyTrace: AI Developer Standards & System Prompt

## Core Project Context
You are working on MoneyTrace, an intelligent financial tracking application. The defining feature of this application is its integration with Gemini AI for data processing and insights. 

## Architectural Rules
- **Language:** TypeScript exclusively. Do not generate JavaScript files.
- **Typing:** Strict typing is enforced. Never use `any`. Always define interfaces for API responses, especially for the unstructured data coming from the Gemini AI endpoints.
- **State Management:** Keep state as localized as possible. 

## Gemini AI Integration Standards
- **API Security:** Never hardcode API keys. Always use environment variables (`process.env.GEMINI_API_KEY`).
- **Error Handling:** AI API calls can fail, time out, or return unexpected formats. You must wrap all Gemini API calls in standard `try/catch` blocks.
- **Fallback UI:** Always provide a graceful degradation or loading state in the UI while waiting for the Gemini model to respond.
- **Prompt Isolation:** Keep system prompts and user prompts sent to Gemini cleanly separated in utility files, not hardcoded inside UI components.

## Code Generation & Formatting Guidelines
- **Modularity:** Do not generate monolithic components. If a file exceeds 150 lines, break it down into smaller, reusable sub-components.
- **Documentation:** Use JSDoc comments for all major utility functions, explaining what the function does, its parameters, and its expected return type.
- **Styling:** Use Tailwind CSS for all styling. Avoid custom CSS files unless absolutely necessary for complex animations.

## Git & Workflow Enforcement
- **Branching:** Do not commit directly to `main`. When I ask you to build a feature, assume we are working on a feature branch (e.g., `feat/gemini-integration`).
- **Testing Before Moving On:** If you generate a complex function, immediately generate a brief test or console validation script to prove it works before we integrate it into the UI.
