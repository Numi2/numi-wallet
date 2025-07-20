export interface PasswordStrength {
  score: number; // 0-4
  label: string; // "Very Weak", "Weak", "Fair", "Good", "Strong"
  color: string; // CSS color for UI
  feedback: string[]; // Array of improvement suggestions
}

/**
 * Check password strength
 * @param password The password to check
 * @returns PasswordStrength object
 */
export function checkPasswordStrength(password: string): PasswordStrength {
  const feedback: string[] = [];
  let score = 0;

  // Length check
  if (password.length >= 8) {
    score += 1;
  } else {
    feedback.push("At least 8 characters");
  }

  // Lowercase check
  if (/[a-z]/.test(password)) {
    score += 1;
  } else {
    feedback.push("Include lowercase letters");
  }

  // Uppercase check
  if (/[A-Z]/.test(password)) {
    score += 1;
  } else {
    feedback.push("Include uppercase letters");
  }

  // Numbers check
  if (/\d/.test(password)) {
    score += 1;
  } else {
    feedback.push("Include numbers");
  }

  // Special characters check
  if (/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
    score += 1;
  } else {
    feedback.push("Include special characters");
  }

  // Determine strength level
  let label: string;
  let color: string;

  switch (score) {
    case 0:
    case 1:
      label = "Very Weak";
      color = "#ef4444"; // red-500
      break;
    case 2:
      label = "Weak";
      color = "#f97316"; // orange-500
      break;
    case 3:
      label = "Fair";
      color = "#eab308"; // yellow-500
      break;
    case 4:
      label = "Good";
      color = "#22c55e"; // green-500
      break;
    case 5:
      label = "Strong";
      color = "#10b981"; // emerald-500
      break;
    default:
      label = "Very Weak";
      color = "#ef4444";
  }

  return {
    score,
    label,
    color,
    feedback: feedback.slice(0, 3) // Limit to 3 suggestions
  };
}

/**
 * Validate password requirements
 * @param password The password to validate
 * @returns True if password meets minimum requirements
 */
export function validatePassword(password: string): boolean {
  const strength = checkPasswordStrength(password);
  return strength.score >= 3; // At least "Fair" strength
}

/**
 * Get password strength percentage
 * @param password The password to check
 * @returns Percentage (0-100)
 */
export function getPasswordStrengthPercentage(password: string): number {
  const strength = checkPasswordStrength(password);
  return (strength.score / 5) * 100;
} 