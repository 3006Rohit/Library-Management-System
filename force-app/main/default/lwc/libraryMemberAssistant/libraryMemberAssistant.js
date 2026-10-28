import { LightningElement } from "lwc";
import startAgentSession from "@salesforce/apex/LibraryMemberAgentController.startSession";
import sendAgentMessage from "@salesforce/apex/LibraryMemberAgentController.sendMessage";
import endAgentSession from "@salesforce/apex/LibraryMemberAgentController.endSession";

const SESSION_KEY = "libraryMemberSession";

function memberToken() {
  try {
    return sessionStorage.getItem(SESSION_KEY);
  } catch {
    return null;
  }
}

const BOT_CLASS = "lib-assistant-message lib-assistant-message-bubble";
const USER_CLASS = "lib-assistant-message lib-librarian-message-bubble";

function errorText(error) {
  return (
    error?.body?.message ||
    error?.message ||
    (typeof error === "string" ? error : "Unknown error")
  );
}

export default class LibraryMemberAssistant extends LightningElement {
  assistantInput = "";
  assistantSessionId;
  assistantSequence = 0;
  assistantBusy = false;
  assistantMessages = [
    {
      id: "welcome",
      className: BOT_CLASS,
      text: "Hello! 👋 I’m your Library Assistant. I can help with your loans, reservations, activity, and finding books in the catalog. How can I help you today?"
    }
  ];

  get assistantQuestions() {
    return [
      "What are my current loans?",
      "When are my books due?",
      "Show my reservations",
      "Summarize my library activity",
      "Search the catalog for books about science",
      "Find books by Agatha Christie"
    ];
  }

  get assistantSendLabel() {
    return this.assistantBusy ? "…" : "➤";
  }

  disconnectedCallback() {
    if (this.assistantSessionId) {
      endAgentSession({
        sessionToken: memberToken(),
        sessionId: this.assistantSessionId
      }).catch(() => undefined);
      this.assistantSessionId = undefined;
    }
  }

  handleAssistantInput(event) {
    this.assistantInput = event.target.value;
  }

  useAssistantPrompt(event) {
    this.assistantInput = event.currentTarget.dataset.question;
    this.sendAssistantMessage();
  }

  async sendAssistantMessage(event) {
    event?.preventDefault();
    const question = this.assistantInput.trim();
    if (!question || this.assistantBusy) return;
    this.assistantMessages = [
      ...this.assistantMessages,
      { id: `question-${Date.now()}`, className: USER_CLASS, text: question }
    ];
    this.assistantInput = "";
    this.assistantBusy = true;
    try {
      if (!this.assistantSessionId) {
        const session = await startAgentSession({
          sessionToken: memberToken()
        });
        this.assistantSessionId = session.sessionId;
        this.assistantSequence = 0;
      }
      this.assistantSequence += 1;
      const response = await sendAgentMessage({
        sessionToken: memberToken(),
        sessionId: this.assistantSessionId,
        sequenceId: this.assistantSequence,
        text: question
      });
      this.assistantMessages = [
        ...this.assistantMessages,
        {
          id: `answer-${Date.now()}`,
          className: BOT_CLASS,
          text: response.message
        }
      ];
    } catch (error) {
      this.assistantMessages = [
        ...this.assistantMessages,
        {
          id: `error-${Date.now()}`,
          className: BOT_CLASS,
          text: `The live assistant could not be opened: ${errorText(error)}`
        }
      ];
      this.assistantSessionId = undefined;
      this.assistantSequence = 0;
    } finally {
      this.assistantBusy = false;
    }
  }

  async clearAssistantChat() {
    if (this.assistantSessionId) {
      await endAgentSession({
        sessionToken: memberToken(),
        sessionId: this.assistantSessionId
      }).catch(() => undefined);
    }
    this.assistantSessionId = undefined;
    this.assistantSequence = 0;
    this.assistantMessages = [];
  }
}
