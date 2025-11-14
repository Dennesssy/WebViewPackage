import React from "react";
import "./GlassBar.css";

export default function GlassBar({
  url,
  setUrl,
  canGoBack,
  canGoForward,
  onBack,
  onForward,
  onReload,
}) {
  const handleKey = (e) => {
    if (e.key === "Enter") onReload();
  };

  return (
    <div className="glass-bar">
      <button
        className="nav-btn"
        onClick={onBack}
        disabled={!canGoBack}
        aria-label="Back"
      >
        ◀︎
      </button>

      <button
        className="nav-btn"
        onClick={onForward}
        disabled={!canGoForward}
        aria-label="Forward"
      >
        ▶︎
      </button>

      <button className="nav-btn" onClick={onReload} aria-label="Reload">
        ↻
      </button>

      <input
        className="url-input"
        type="text"
        value={url}
        onChange={(e) => setUrl(e.target.value)}
        onKeyDown={handleKey}
        placeholder="Enter URL"
      />
    </div>
  );
}
