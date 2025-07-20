const SESSION_TIMEOUT_KEY = "numi_wallet_session_timeout";
const SESSION_ACTIVITY_KEY = "numi_wallet_last_activity";
const DEFAULT_TIMEOUT = 5 * 60 * 1000; // 5 minutes in milliseconds

/**
 * Set session timeout duration
 * @param timeoutMs Timeout in milliseconds
 */
export function setSessionTimeout(timeoutMs: number): void {
  if (typeof window !== "undefined") {
    localStorage.setItem(SESSION_TIMEOUT_KEY, timeoutMs.toString());
  }
}

/**
 * Get current session timeout duration
 * @returns Timeout in milliseconds
 */
export function getSessionTimeout(): number {
  if (typeof window !== "undefined") {
    const timeout = localStorage.getItem(SESSION_TIMEOUT_KEY);
    return timeout ? parseInt(timeout) : DEFAULT_TIMEOUT;
  }
  return DEFAULT_TIMEOUT;
}

/**
 * Update last activity timestamp
 */
export function updateActivity(): void {
  if (typeof window !== "undefined") {
    localStorage.setItem(SESSION_ACTIVITY_KEY, Date.now().toString());
  }
}

/**
 * Check if session has expired
 * @returns True if session has expired
 */
export function isSessionExpired(): boolean {
  if (typeof window === "undefined") {
    return false;
  }

  const lastActivity = localStorage.getItem(SESSION_ACTIVITY_KEY);
  if (!lastActivity) {
    return true;
  }

  const timeout = getSessionTimeout();
  const now = Date.now();
  const lastActivityTime = parseInt(lastActivity);

  return (now - lastActivityTime) > timeout;
}

/**
 * Clear session data
 */
export function clearSession(): void {
  if (typeof window !== "undefined") {
    localStorage.removeItem(SESSION_ACTIVITY_KEY);
  }
}

/**
 * Initialize session monitoring
 * @param onExpire Callback when session expires
 */
export function initSessionMonitoring(onExpire: () => void): () => void {
  if (typeof window === "undefined") {
    return () => {};
  }

  // Update activity on user interactions
  const updateActivityOnInteraction = () => {
    updateActivity();
  };

  // Add event listeners for user activity
  const events = ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart', 'click'];
  events.forEach(event => {
    document.addEventListener(event, updateActivityOnInteraction, true);
  });

  // Check for session expiry every 30 seconds
  const interval = setInterval(() => {
    if (isSessionExpired()) {
      onExpire();
    }
  }, 30000);

  // Initial activity update
  updateActivity();

  // Return cleanup function
  return () => {
    events.forEach(event => {
      document.removeEventListener(event, updateActivityOnInteraction, true);
    });
    clearInterval(interval);
  };
} 