export function limit(value, fallback, ceiling) {
  if (value == null || value === "") return fallback;
  const n = Number(value);
  return Number.isSafeInteger(n) && n >= 0 && n <= ceiling ? n : 0;
}
export function chatInput(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  if (!["atlas", "pixel", "mesh"].includes(body.cubot)) return null;
  if (typeof body.prompt !== "string" || !body.prompt.trim() || new TextEncoder().encode(body.prompt).length > 2048) return null;
  if (typeof body.system !== "string" || new TextEncoder().encode(body.system).length > 24576) return null;
  return { cubot: body.cubot, prompt: body.prompt, system: body.system };
}
export function claimsValid(c, project, now) {
  return !!c && c.aud === project && c.iss === "https://securetoken.google.com/" + project &&
    typeof c.sub === "string" && c.sub.length > 0 && c.sub.length <= 128 &&
    Number.isFinite(c.exp) && c.exp > now && Number.isFinite(c.iat) && c.iat <= now &&
    Number.isFinite(c.auth_time) && c.auth_time <= now &&
    c.firebase?.sign_in_provider === "anonymous";
}
export function quotaPlan(kind, uid, ip, env) {
  if (kind === "chat") return [
    ["chat:global", limit(env.DAILY_GLOBAL_REQUESTS,100,100000)],
    ["chat:user:"+uid, limit(env.DAILY_USER_REQUESTS,10,1000)],
    ["chat:ip:"+ip, limit(env.DAILY_IP_REQUESTS,30,10000)]
  ];
  return [[kind+":global", 500], [kind+":ip:"+ip, kind === "guest" ? 5 : 30]];
}
