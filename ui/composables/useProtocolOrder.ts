import type { PermedProtocol } from "~/types";

const PROTOCOL_PRIORITY: Record<string, number> = {
  ssh: 10,
  sftp: 20
};

function protocolPriority(name: string) {
  return PROTOCOL_PRIORITY[name.toLowerCase()] ?? 100;
}

export function sortProtocolNames(protocols: string[]) {
  return [...protocols].sort((a, b) => {
    const priorityDiff = protocolPriority(a) - protocolPriority(b);
    if (priorityDiff !== 0) return priorityDiff;
    return 0;
  });
}

export function sortPermedProtocols(protocols: PermedProtocol[]) {
  return [...(protocols || [])].sort((a, b) => {
    const priorityDiff = protocolPriority(a?.name || "") - protocolPriority(b?.name || "");
    if (priorityDiff !== 0) return priorityDiff;
    return 0;
  });
}
