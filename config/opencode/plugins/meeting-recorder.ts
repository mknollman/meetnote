import type { Plugin } from "@opencode-ai/plugin"
import { tool } from "@opencode-ai/plugin"
import { $ } from "bun"

const NORMAL_PROMPT = `You are a meeting assistant. Given the following meeting transcript, produce a clean markdown document with exactly two sections:

## Summary
A concise paragraph covering the main points discussed.

## Action Items
A bulleted list of tasks, owners (if mentioned), and deadlines (if mentioned). If no action items are discussed, write "None."

Do not add any other sections. Do not include the transcript.`

const TRAINING_PROMPT = `You are a training assistant. Given the following training transcript, produce a clean markdown document with exactly these sections:

## Summary
A concise paragraph covering the main topics of the training session.

## Key Concepts
A thorough bullet list of every concept, term, procedure, or idea taught, with a brief definition of each based on what was actually said.

## Details & Examples
Expand on each key concept with the details, steps, examples, and explanations given. This section should be in-depth - someone who missed the training should be able to learn from it.

## Action Items
A bulleted list of tasks, practice items, or follow-ups, with owners (if mentioned) and deadlines (if mentioned). If none, write "None."

## Open Questions
Anything left unresolved, unclear, or marked for follow-up. If none, write "None."

Do not add any other sections. Do not include the transcript.`

export const MeetingRecorderPlugin: Plugin = async () => {
  return {
    tool: {
      meeting_start: tool({
        description:
          "Start recording a meeting. Records mic + system audio and transcribes continuously. Press again to stop and summarize.",
        args: {
          title: tool.schema
            .string()
            .optional()
            .describe("Optional meeting title."),
        },
        async execute(args) {
          const titleArg = args.title ? `-t "${args.title}"` : ""
          const result = await $`voxtype meeting start ${titleArg} --diarization ml`.quiet()
          return {
            title: "Meeting recording started",
            output: `Recording…\n\n${result.stdout}\n\nStop with the meeting_stop tool when done.`,
          }
        },
      }),

      meeting_stop: tool({
        description:
          "Stop the current meeting recording and return a markdown summary. Mode 'normal' gives Summary + Action Items; mode 'training' gives in-depth learning-focused notes (Key Concepts, Details & Examples, Open Questions).",
        args: {
          mode: tool.schema
            .string()
            .optional()
            .describe('Summary mode: "normal" (default) or "training".'),
        },
        async execute(args) {
          const mode = args.mode === "training" ? "training" : "normal"
          await $`voxtype meeting stop`.quiet()

          const transcript = await $`voxtype meeting export latest -f text --timestamps --speakers`.quiet()

          if (!transcript.stdout.trim()) {
            return { title: "Meeting stopped", output: "No transcript captured." }
          }

          const prompt = mode === "training" ? TRAINING_PROMPT : NORMAL_PROMPT
          const { stdout: summary } = await $`ollama run llama3.2 ${prompt}\n\n--- TRANSCRIPT ---\n${transcript.stdout}`.quiet()

          const md = mode === "training" ? `# Training Notes\n\n${summary.trim()}` : `# Meeting Summary\n\n${summary.trim()}`

          const suffix = mode === "training" ? "-training" : ""
          const outPath = `${process.env.HOME}/Documents/meetings/meeting-${new Date().toISOString().slice(0, 16).replace("T", "_")}${suffix}.md`
          await $`mkdir -p ${process.env.HOME}/Documents/meetings`.quiet()
          await Bun.write(outPath, md)

          return {
            title: "Meeting summary",
            output: `${md}\n\nSaved to ${outPath}`,
          }
        },
      }),
    },
  }
}

export default MeetingRecorderPlugin
