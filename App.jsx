import React, { useRef, useState, useEffect } from "react";
import GlassBar from "./GlassBar";
import "./App.css";

export default function App() {
  const iframeRef = useRef(null);

  const [url, setUrl] = useState("https://www.apple.com");
  const [canGoBack, setCanGoBack] = useState(false);
  const [canGoForward, setCanGoForward] = useState(false);
  const historyStack = useRef([]);
  const forwardStack = useRef([]);

  const loadURL = (target) => {
    if (!target) return;
    const normalized = normalizeURL(target);
    setUrl(normalized);
    iframeRef.current.src = normalized;
  };

  const normalizeURL = (raw) => {
    let trimmed = raw.trim();
    if (!/^https?:\/\//i.test(trimmed)) trimmed = "https://" + trimmed;
    return trimmed;
  };

  const goBack = () => {
    if (historyStack.current.length > 1) {
      forwardStack.current.unshift(historyStack.current.pop());
      const previous = historyStack.current[historyStack.current.length - 1];
      loadURL(previous);
    }
  };

  const goForward = () => {
    if (forwardStack.current.length > 0) {
      const next = forwardStack.current.shift();
      historyStack.current.push(next);
      loadURL(next);
    }
  };

  const reload = () => {
    iframeRef.current.contentWindow.location.reload();
  };

  const onLoad = () => {
    const current = iframeRef.current.contentWindow.location.href;
    if (historyStack.current[historyStack.current.length - 1] !== current) {
      historyStack.current.push(current);
      forwardStack.current = [];
    }
    setCanGoBack(historyStack.current.length > 1);
    setCanGoForward(forwardStack.current.length > 0);
    setUrl(current);
  };

  useEffect(() => {
    loadURL(url);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="app-root">
      <GlassBar
        url={url}
        setUrl={setUrl}
        canGoBack={canGoBack}
        canGoForward={canGoForward}
        onBack={goBack}
        onForward={goForward}
        onReload={reload}
      />

      <iframe
        ref={iframeRef}
        title="webview"
        sandbox="allow-scripts allow-same-origin allow-forms"
        style={{ flex: 1, border: "none", width: "100%" }}
        onLoad={onLoad}
      />
    </div>
  );
}
