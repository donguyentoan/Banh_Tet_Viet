import { handleAdminAuth, type ApiRequest, type ApiResponse } from "../../server/admin-auth.js";

export default async function handler(req: ApiRequest, res: ApiResponse) {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  return handleAdminAuth(req, res, "session");
}
