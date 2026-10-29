import { Controller } from "@hotwired/stimulus";

/**
 * Keeps the form honest while a submission is in flight: the button cannot be
 * pressed twice, and a validation response returns focus to the field.
 */
export class TaskFormController extends Controller<HTMLFormElement> {
  static targets = ["submit", "title"];

  declare readonly submitTarget: HTMLButtonElement;
  declare readonly titleTarget: HTMLInputElement;

  connect() {
    this.element.addEventListener("turbo:submit-start", this.handleStart);
    this.element.addEventListener("turbo:submit-end", this.handleEnd);
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.handleStart);
    this.element.removeEventListener("turbo:submit-end", this.handleEnd);
  }

  private handleStart = () => {
    this.submitTarget.disabled = true;
    this.element.setAttribute("aria-busy", "true");
  };

  private handleEnd = () => {
    this.submitTarget.disabled = false;
    this.element.removeAttribute("aria-busy");

    if (this.element.isConnected) {
      this.titleTarget.focus();
    }
  };
}
