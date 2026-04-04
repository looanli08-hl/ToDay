// ─── YouTube Content Script ───
// Detects video info, tracks watch progress, reports to background service worker.

(function () {
  "use strict";

  console.log("[Attune] YouTube perception active");

  // ─── State ───

  let currentVideoId = null;
  let videoElement = null;
  let progressInterval = null;

  // ─── Helpers ───

  function getVideoIdFromUrl() {
    const params = new URLSearchParams(window.location.search);
    return params.get("v") || null;
  }

  function getVideoTitle() {
    const metaTitle = document.querySelector(
      "h1.ytd-watch-metadata yt-formatted-string"
    );
    if (metaTitle && metaTitle.textContent.trim()) {
      return metaTitle.textContent.trim();
    }
    // Fallback: strip " - YouTube" suffix from document title
    const docTitle = document.title;
    return docTitle.replace(/\s*-\s*YouTube\s*$/, "").trim() || docTitle;
  }

  function getChannelName() {
    const channelEl = document.querySelector(
      "ytd-channel-name yt-formatted-string a"
    );
    return channelEl ? channelEl.textContent.trim() : "Unknown";
  }

  function buildEventData() {
    const vid = videoElement;
    return {
      videoId: currentVideoId,
      title: getVideoTitle(),
      channel: getChannelName(),
      duration: vid ? Math.round(vid.duration || 0) : 0,
      currentTime: vid ? Math.round(vid.currentTime || 0) : 0,
      completionPercent:
        vid && vid.duration
          ? Math.round((vid.currentTime / vid.duration) * 100)
          : 0,
      paused: vid ? vid.paused : true,
      url: window.location.href,
      timestamp: Date.now(),
    };
  }

  function sendEvent(eventName) {
    chrome.runtime.sendMessage({
      type: "youtube_event",
      event: eventName,
      data: buildEventData(),
    });
  }

  // ─── Video Element Binding ───

  function attachVideoListeners(video) {
    if (videoElement === video) return;
    detachVideoListeners();
    videoElement = video;

    video.addEventListener("play", onPlay);
    video.addEventListener("pause", onPause);
    video.addEventListener("ended", onEnded);

    // Progress reporting every 5 seconds
    progressInterval = setInterval(() => {
      if (videoElement && !videoElement.paused && currentVideoId) {
        sendEvent("video_progress");
      }
    }, 5000);
  }

  function detachVideoListeners() {
    if (videoElement) {
      videoElement.removeEventListener("play", onPlay);
      videoElement.removeEventListener("pause", onPause);
      videoElement.removeEventListener("ended", onEnded);
      videoElement = null;
    }
    if (progressInterval) {
      clearInterval(progressInterval);
      progressInterval = null;
    }
  }

  function onPlay() {
    sendEvent("video_play");
  }

  function onPause() {
    sendEvent("video_pause");
  }

  function onEnded() {
    sendEvent("video_ended");
  }

  // ─── Video Detection & SPA Navigation ───

  function handleVideoChange() {
    const newVideoId = getVideoIdFromUrl();

    // Not on a watch page
    if (!newVideoId) {
      if (currentVideoId) {
        sendEvent("video_leave");
        currentVideoId = null;
        detachVideoListeners();
      }
      return;
    }

    // Same video — nothing to do
    if (newVideoId === currentVideoId) return;

    // Report old video as left
    if (currentVideoId) {
      sendEvent("video_leave");
    }

    // Delay slightly for DOM to update after SPA navigation
    setTimeout(() => {
      currentVideoId = newVideoId;
      waitForVideo();
      sendEvent("video_start");
    }, 1500);
  }

  function waitForVideo() {
    const video = document.querySelector("video");
    if (video) {
      attachVideoListeners(video);
      return;
    }

    // Video element not in DOM yet — watch for it
    const observer = new MutationObserver((mutations, obs) => {
      const vid = document.querySelector("video");
      if (vid) {
        obs.disconnect();
        attachVideoListeners(vid);
      }
    });

    observer.observe(document.body, { childList: true, subtree: true });

    // Safety timeout: stop observing after 15s
    setTimeout(() => observer.disconnect(), 15000);
  }

  // ─── Listen for SPA Navigation ───

  // YouTube fires this custom event on client-side navigations
  window.addEventListener("yt-navigate-finish", () => handleVideoChange());
  window.addEventListener("popstate", () => handleVideoChange());

  // ─── Initial Load ───

  handleVideoChange();
})();
