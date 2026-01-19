import { loadBoundaries, loadProjectContext, loadRules } from "../config/loader.ts";

interface PromptOptions {
	task: string;
	autoCommit?: boolean;
	workDir?: string;
}

/**
 * Build the full prompt with project context, rules, boundaries, and task
 */
export function buildPrompt(options: PromptOptions): string {
	const { task, autoCommit = true, workDir = process.cwd() } = options;

	const parts: string[] = [];

	// Add project context if available
	const context = loadProjectContext(workDir);
	if (context) {
		parts.push(`## Project Context\n${context}`);
	}

	// Add rules if available
	const rules = loadRules(workDir);
	if (rules.length > 0) {
		parts.push(`## Rules (you MUST follow these)\n${rules.join("\n")}`);
	}

	// Add boundaries
	const boundaries = loadBoundaries(workDir);
	if (boundaries.length > 0) {
		parts.push(`## Boundaries\nDo NOT modify these files/directories:\n${boundaries.join("\n")}`);
	}

	// Add the task
	parts.push(`## Task\n${task}`);

	// Add instructions
	const instructions = [
		"1. Implement the task described above",
		"2. Write tests if appropriate",
		"3. Ensure the code works correctly",
	];

	if (autoCommit) {
		instructions.push("4. Commit your changes with a descriptive message");
	}

	parts.push(`## Instructions\n${instructions.join("\n")}`);

	// Add final note
	parts.push("Keep changes focused and minimal. Do not refactor unrelated code.");

	return parts.join("\n\n");
}

/**
 * Build a prompt for parallel agent execution
 */
export function buildParallelPrompt(task: string, progressFile: string): string {
	return `You are working on a specific task. Focus ONLY on this task:

TASK: ${task}

Instructions:
1. Implement this specific task completely
2. Write tests if appropriate
3. Update ${progressFile} with what you did
4. Commit your changes with a descriptive message

Do NOT modify PRD.md or mark tasks complete - that will be handled separately.
Focus only on implementing: ${task}`;
}
