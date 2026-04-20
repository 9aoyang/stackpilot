export type Region = "us" | "eu" | "apac";

export function regionFromAccount(accountId: string): Region {
  if (accountId.startsWith("acct_eu_")) return "eu";
  if (accountId.startsWith("acct_apac_")) return "apac";
  return "us";
}
