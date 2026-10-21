#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "command.h"
#include "iso8601.h"

using terminal_command::Action;
using terminal_command::AckStatus;
using terminal_command::Handler;
using terminal_command::History;
using terminal_command::Parsed;
using terminal_command::Verdict;

namespace {

void copyText(char* destination, size_t size, const char* source) {
  strncpy(destination, source, size - 1);
  destination[size - 1] = '\0';
}

Parsed command(const char* id, Action action, uint64_t expiresAt) {
  Parsed parsed;
  parsed.version = 1;
  copyText(parsed.terminalId, sizeof parsed.terminalId, "terminal-dev-01");
  copyText(parsed.commandId, sizeof parsed.commandId, id);
  parsed.action = action;
  parsed.actionValid = true;
  parsed.expiresAt = expiresAt;
  parsed.expiresAtValid = true;
  return parsed;
}

int actuations = 0;
Action lastAction = Action::deny;
bool actuatorResult = true;

bool actuator(Action action) {
  ++actuations;
  lastAction = action;
  return actuatorResult;
}

void testIso8601() {
  uint64_t epoch = 0;
  assert(iso8601::toEpoch("1970-01-01T00:00:00Z", epoch));
  assert(epoch == 0);
  assert(iso8601::toEpoch("2026-10-19T19:30:13Z", epoch));
  assert(epoch == 1792438213ULL);
  assert(iso8601::toEpoch("2026-10-19T19:30:13.400Z", epoch));
  assert(epoch == 1792438213ULL);
  assert(iso8601::toEpoch("2024-02-29T00:00:00Z", epoch));
  assert(epoch == 1709164800ULL);
  assert(iso8601::toEpoch("2038-01-19T03:14:08Z", epoch));
  assert(epoch == 2147483648ULL);

  assert(!iso8601::toEpoch("", epoch));
  assert(!iso8601::toEpoch("2026-10-19T19:30:13", epoch));
  assert(!iso8601::toEpoch("2026-10-19T19:30:13+01:00", epoch));
  assert(!iso8601::toEpoch("2026-13-19T19:30:13Z", epoch));
  assert(!iso8601::toEpoch("2026-10-32T19:30:13Z", epoch));
  assert(!iso8601::toEpoch("2026-10-19T24:00:00Z", epoch));
  assert(!iso8601::toEpoch("ontem", epoch));

  char text[32];
  assert(iso8601::fromEpoch(0, text, sizeof text));
  assert(strcmp(text, "1970-01-01T00:00:00.000Z") == 0);
  assert(iso8601::fromEpoch(1792438213ULL, text, sizeof text));
  assert(strcmp(text, "2026-10-19T19:30:13.000Z") == 0);
  assert(iso8601::fromEpoch(2147483648ULL, text, sizeof text));
  assert(strcmp(text, "2038-01-19T03:14:08.000Z") == 0);
  assert(!iso8601::fromEpoch(0, text, 8));  // buffer menor que o texto

  char roundTrip[32];
  assert(iso8601::fromEpoch(1792438213ULL, roundTrip, sizeof roundTrip));
  assert(iso8601::toEpoch(roundTrip, epoch));
  assert(epoch == 1792438213ULL);
}

void testDecision() {
  const char* local = "terminal-dev-01";

  terminal_command::Decision decision = terminal_command::decide(command("cmd", Action::open, 2000), local, 1000);
  assert(decision.verdict == Verdict::execute);
  assert(decision.reason == nullptr);

  decision = terminal_command::decide(command("cmd", Action::deny, 2000), local, 1000);
  assert(decision.verdict == Verdict::execute);

  decision = terminal_command::decide(command("cmd", Action::open, 2000), local, 2000);
  assert(decision.verdict == Verdict::expired);  // expiresAt = agora ja venceu

  decision = terminal_command::decide(command("cmd", Action::open, 2000), local, 2001);
  assert(decision.verdict == Verdict::expired);
  assert(decision.reason == nullptr);

  Parsed parsed = command("cmd", Action::open, 2000);
  parsed.version = 2;
  decision = terminal_command::decide(parsed, local, 1000);
  assert(decision.verdict == Verdict::rejected);
  assert(strcmp(decision.reason, "unsupported_version") == 0);

  parsed = command("cmd", Action::open, 2000);
  copyText(parsed.terminalId, sizeof parsed.terminalId, "terminal-99");
  decision = terminal_command::decide(parsed, local, 1000);
  assert(decision.verdict == Verdict::rejected);
  assert(strcmp(decision.reason, "terminal_mismatch") == 0);

  parsed = command("cmd", Action::open, 2000);
  parsed.actionValid = false;
  decision = terminal_command::decide(parsed, local, 1000);
  assert(decision.verdict == Verdict::rejected);
  assert(strcmp(decision.reason, "unsupported_action") == 0);

  parsed = command("cmd", Action::open, 2000);
  parsed.expiresAtValid = false;
  decision = terminal_command::decide(parsed, local, 1000);
  assert(decision.verdict == Verdict::rejected);
  assert(strcmp(decision.reason, "invalid_expires_at") == 0);
}

void testHistory() {
  History history;
  AckStatus status = AckStatus::executed;
  assert(!history.lookup("cmd-0", status));

  char id[16];
  for (int i = 0; i < 8; ++i) {
    snprintf(id, sizeof id, "cmd-%d", i);
    history.remember(id, AckStatus::expired);
  }
  assert(history.lookup("cmd-0", status));
  assert(status == AckStatus::expired);
  assert(history.lookup("cmd-7", status));

  history.remember("cmd-8", AckStatus::executed);
  assert(!history.lookup("cmd-0", status));  // janela descarta a mais antiga
  assert(history.lookup("cmd-1", status));
  assert(history.lookup("cmd-8", status));
  assert(status == AckStatus::executed);
}

void testHandler() {
  Handler handler;
  handler.configure("terminal-dev-01", actuator);
  actuations = 0;

  const terminal_command::Ack* ack = handler.handle(command("cmd-1", Action::open, 2000), 1000, true);
  assert(ack != nullptr);
  assert(strcmp(ack->commandId, "cmd-1") == 0);
  assert(strcmp(ack->status, "executed") == 0);
  assert(ack->reason == nullptr);
  assert(actuations == 1);
  assert(lastAction == Action::open);

  ack = handler.handle(command("cmd-1", Action::open, 2000), 1000, true);
  assert(strcmp(ack->status, "executed") == 0);
  assert(strcmp(ack->reason, "duplicate") == 0);
  assert(actuations == 1);

  ack = handler.handle(command("cmd-2", Action::open, 500), 1000, true);
  assert(strcmp(ack->status, "expired") == 0);
  assert(actuations == 1);
  ack = handler.handle(command("cmd-2", Action::open, 500), 1000, true);
  assert(strcmp(ack->status, "expired") == 0);
  assert(strcmp(ack->reason, "duplicate") == 0);

  ack = handler.handle(command("cmd-3", Action::open, 2000), 1000, false);
  assert(strcmp(ack->status, "rejected") == 0);
  assert(strcmp(ack->reason, "clock_unsynced") == 0);
  assert(actuations == 1);

  actuatorResult = false;
  ack = handler.handle(command("cmd-4", Action::open, 2000), 1000, true);
  assert(strcmp(ack->status, "rejected") == 0);
  assert(strcmp(ack->reason, "door_busy") == 0);
  assert(actuations == 2);
  actuatorResult = true;

  ack = handler.handle(command("cmd-5", Action::deny, 2000), 1000, true);
  assert(strcmp(ack->status, "executed") == 0);
  assert(lastAction == Action::deny);

  Handler unplugged;
  unplugged.configure("terminal-dev-01", nullptr);
  ack = unplugged.handle(command("cmd-6", Action::open, 2000), 1000, true);
  assert(strcmp(ack->status, "rejected") == 0);
  assert(strcmp(ack->reason, "door_unavailable") == 0);

  Parsed anonymous = command("", Action::open, 2000);
  assert(handler.handle(anonymous, 1000, true) == nullptr);  // sem commandId nao ha ACK
}

void testDuplicateWindow() {
  Handler handler;
  handler.configure("terminal-dev-01", actuator);
  actuations = 0;

  char ids[8][8];
  for (int i = 0; i < 8; ++i) {
    snprintf(ids[i], sizeof ids[i], "dup-%d", i);
    const terminal_command::Ack* ack = handler.handle(command(ids[i], Action::open, 5000), 1000, true);
    assert(strcmp(ack->status, "executed") == 0);
  }
  assert(actuations == 8);

  const terminal_command::Ack* ack = handler.handle(command(ids[0], Action::open, 5000), 1000, true);
  assert(strcmp(ack->reason, "duplicate") == 0);
  ack = handler.handle(command(ids[1], Action::open, 5000), 1000, true);
  assert(strcmp(ack->reason, "duplicate") == 0);
  assert(actuations == 8);  // a duplicata nao pode expulsar ids[1]
}

}  // namespace

int main() {
  testIso8601();
  testDecision();
  testHistory();
  testHandler();
  testDuplicateWindow();
  puts("command: iso8601, decisao, dedup por commandId e ACK OK");
}
