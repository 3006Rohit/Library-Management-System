import { LightningElement } from "lwc";
import getReadingChallenges from "@salesforce/apex/LibraryMemberSessionController.getReadingChallenges";
import enrollReadingChallenge from "@salesforce/apex/LibraryMemberSessionController.enrollReadingChallenge";
import leaveReadingChallenge from "@salesforce/apex/LibraryMemberSessionController.leaveReadingChallenge";
import syncReadingAchievements from "@salesforce/apex/LibraryMemberSessionController.syncReadingAchievements";
import getMyReadingAchievements from "@salesforce/apex/LibraryMemberSessionController.getMyReadingAchievements";
import setReadingLeaderboardOptIn from "@salesforce/apex/LibraryMemberSessionController.setReadingLeaderboardOptIn";
import getReadingLeaderboard from "@salesforce/apex/LibraryMemberSessionController.getReadingLeaderboard";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LibraryMemberChallenges extends LightningElement {
  rows = [];
  loading = false;
  error;
  achievements = [];
  leaderboard = [];
  leaderboardOptIn = false;
  leaderboardChallenge;
  sessionToken = sessionStorage.getItem("libraryMemberSession");

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = undefined;
    try {
      await syncReadingAchievements({ sessionToken: this.sessionToken });
      const [rows, achievements] = await Promise.all([
        getReadingChallenges({ sessionToken: this.sessionToken }),
        getMyReadingAchievements({ sessionToken: this.sessionToken })
      ]);
      this.achievements = achievements || [];
      this.rows = this.decorate(rows || []);
      this.leaderboardOptIn = this.rows.some((row) => row.leaderboardOptedIn);
    } catch (error) {
      this.error =
        error?.body?.message || error?.message || "Unable to load challenges.";
    } finally {
      this.loading = false;
    }
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  get hasAchievements() {
    return this.achievements.length > 0;
  }

  get hasLeaderboard() {
    return this.leaderboard.length > 0;
  }

  get leaderboardTitle() {
    return this.leaderboardChallenge?.name || "Challenge leaderboard";
  }

  async enroll(event) {
    await this.mutate(
      event.currentTarget.dataset.id,
      enrollReadingChallenge,
      "Challenge joined"
    );
  }

  async leave(event) {
    const challengeId = event.currentTarget.dataset.id;
    try {
      await leaveReadingChallenge({
        sessionToken: this.sessionToken,
        challengeId
      });
      this.rows = this.rows.map((row) => {
        return row.id === challengeId
          ? { ...row, enrollmentStatus: undefined }
          : row;
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Challenge left",
          message: "You can rejoin any time.",
          variant: "success"
        })
      );
    } catch (error) {
      this.toast("Could not leave challenge", error, "error");
    }
  }

  async toggleLeaderboard(event) {
    this.leaderboardOptIn = event.target.checked;
    try {
      await setReadingLeaderboardOptIn({
        sessionToken: this.sessionToken,
        optIn: this.leaderboardOptIn
      });
      this.toast(
        "Leaderboard preference saved",
        "Your anonymous alias will be used when opted in.",
        "success"
      );
    } catch (error) {
      this.leaderboardOptIn = !this.leaderboardOptIn;
      this.toast("Could not save leaderboard preference", error, "error");
    }
  }

  async viewLeaderboard(event) {
    const challengeId = event.currentTarget.dataset.id;
    this.leaderboardChallenge = this.rows.find((row) => row.id === challengeId);
    try {
      this.leaderboard =
        (await getReadingLeaderboard({
          sessionToken: this.sessionToken,
          challengeId
        })) || [];
    } catch (error) {
      this.toast("Could not load leaderboard", error, "error");
    }
  }

  async mutate(challengeId, action, title) {
    try {
      const updated = await action({
        sessionToken: this.sessionToken,
        challengeId
      });
      this.rows = this.rows.map((row) => {
        return row.id === challengeId ? this.decorate([updated])[0] : row;
      });
      this.dispatchEvent(
        new ShowToastEvent({ title, message: "", variant: "success" })
      );
    } catch (error) {
      this.toast("Could not update challenge", error, "error");
    }
  }

  toast(title, error, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message: error?.body?.message || error?.message || "Try again.",
        variant
      })
    );
  }

  decorate(rows) {
    return rows.map((row) => {
      const ratio = row.goalCount
        ? Math.min((row.progressCount || 0) / row.goalCount, 1)
        : 0;
      return { ...row, progressStyle: `width:${Math.round(ratio * 100)}%` };
    });
  }
}
