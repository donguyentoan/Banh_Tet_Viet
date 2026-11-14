import type { FocusEvent } from "react"
export { cn } from "cn"

/**
 * Dùng cho onFocus của input số: nếu đang là "0" thì xoá trống để gõ luôn,
 * còn không thì bôi đen để gõ đè (tránh ra "081" trên mobile).
 */
export function clearZeroOnFocus(event: FocusEvent<HTMLInputElement>) {
  const input = event.currentTarget;
  if (input.value === "0") input.value = "";
  else input.select();
}
