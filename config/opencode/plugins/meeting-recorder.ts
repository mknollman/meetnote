import type { Plugin } from "@opencode-ai/plugin"
import { tool } from "@opencode-ai/plugin"
import { $ } from "bun"

const SUMMARY_PROMPT = `You are a meeting assistant. Given the following meeting transcript, produce a clean markdown document with exactly two sections:

## Summary
A concise paragraph covering the main points discussed.

## Action Items
A bulleted list of tasks, owners (if mentioned), and deadlines (if mentioned). If no action items are discussed, write "None."

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
          "Stop the current meeting recording and return a markdown summary with Summary and Action Items.",
        args: {},
        async execute() {
          await $`voxtype meeting stop`.quiet()

          const transcript = await $`voxtype meeting export latest -f text --timestamps --speakers`.quiet()

          if (!transcript.stdout.trim()) {
            return { title: "Meeting stopped", output: "No transcript captured." }
          }

          const { stdout: summary } = await $`ollama run llama3.2 ${SUMMARY_PROMPT}\n\n--- TRANSCRIPT ---\n${transcript.stdout}`.quiet()

          const md = `# Meeting Summary\n\n${summary.trim()}`

          const outPath = `${process.env.HOME}/Documents/meetings/meeting-${new Date().toISOString().slice(0, 16).replace("T", "_")}.md`
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
