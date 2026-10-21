#pragma once

#include <stdint.h>
#include <string.h>

// Regras do comando v1 (docs/architecture/contratos-mqtt.md) sem dependencia de
// Arduino: validacao, prazo, dedup por commandId e o ACK resultante.
namespace terminal_command {

enum class Action { open, deny };

struct Parsed {
  int version = 0;
  char terminalId[65] = {0};
  char commandId[37] = {0};
  Action action = Action::deny;
  bool actionValid = false;
  uint64_t expiresAt = 0;
  bool expiresAtValid = false;
};

enum class Verdict { execute, rejected, expired };

struct Decision {
  Verdict verdict;
  const char* reason;
};

inline Decision decide(const Parsed& command, const char* localTerminalId, uint64_t nowEpoch) {
  if (command.version != 1) return Decision{Verdict::rejected, "unsupported_version"};
  if (localTerminalId == nullptr || strcmp(command.terminalId, localTerminalId) != 0) {
    return Decision{Verdict::rejected, "terminal_mismatch"};
  }
  if (!command.actionValid) return Decision{Verdict::rejected, "unsupported_action"};
  if (!command.expiresAtValid) return Decision{Verdict::rejected, "invalid_expires_at"};
  if (nowEpoch >= command.expiresAt) return Decision{Verdict::expired, nullptr};
  return Decision{Verdict::execute, nullptr};
}

enum class AckStatus { executed, rejected, expired };

inline const char* statusName(AckStatus status) {
  switch (status) {
    case AckStatus::executed:
      return "executed";
    case AckStatus::rejected:
      return "rejected";
    case AckStatus::expired:
      return "expired";
  }
  return "rejected";
}

// Janela das ultimas respostas: QoS 1 pode reentregar o mesmo comando, e a
// segunda copia precisa receber o ACK anterior sem acionar a cancela de novo.
class History {
 public:
  static const uint8_t kCapacity = 8;

  bool lookup(const char* commandId, AckStatus& status) const {
    if (commandId == nullptr || commandId[0] == '\0') return false;
    for (uint8_t i = 0; i < count_; ++i) {
      if (strncmp(entries_[i].id, commandId, sizeof entries_[i].id) == 0) {
        status = entries_[i].status;
        return true;
      }
    }
    return false;
  }

  void remember(const char* commandId, AckStatus status) {
    if (commandId == nullptr || commandId[0] == '\0') return;
    uint8_t slot;
    if (count_ < kCapacity) {
      slot = static_cast<uint8_t>((head_ + count_) % kCapacity);
      ++count_;
    } else {
      slot = head_;
      head_ = static_cast<uint8_t>((head_ + 1) % kCapacity);
    }
    copyText(entries_[slot].id, sizeof entries_[slot].id, commandId);
    entries_[slot].status = status;
  }

 private:
  struct Entry {
    char id[37];
    AckStatus status;
  };

  static void copyText(char* destination, size_t size, const char* source) {
    strncpy(destination, source, size - 1);
    destination[size - 1] = '\0';
  }

  Entry entries_[kCapacity] = {};
  uint8_t head_ = 0;
  uint8_t count_ = 0;
};

struct Ack {
  const char* commandId = nullptr;
  const char* status = nullptr;
  const char* reason = nullptr;
};

class Handler {
 public:
  using Actuator = bool (*)(Action);

  void configure(const char* localTerminalId, Actuator actuator) {
    if (localTerminalId != nullptr) {
      strncpy(localId_, localTerminalId, sizeof localId_ - 1);
      localId_[sizeof localId_ - 1] = '\0';
    }
    actuator_ = actuator;
  }

  // Retorna o ACK a publicar ou nullptr quando o comando nem pode ser
  // correlacionado (sem commandId). O ponteiro vale ate a proxima chamada.
  const Ack* handle(const Parsed& command, uint64_t nowEpoch, bool clockValid) {
    if (command.commandId[0] == '\0') return nullptr;

    AckStatus previous;
    if (history_.lookup(command.commandId, previous)) {
      // Nao reinserir a duplicata: ela empurraria um comando distinto para fora
      // da janela e permitiria uma segunda atuacao do mesmo comando.
      ack_.commandId = command.commandId;
      ack_.status = statusName(previous);
      ack_.reason = "duplicate";
      return &ack_;
    }
    if (!clockValid) return record(command.commandId, AckStatus::rejected, "clock_unsynced");

    const Decision decision = decide(command, localId_, nowEpoch);
    if (decision.verdict == Verdict::expired) {
      return record(command.commandId, AckStatus::expired, nullptr);
    }
    if (decision.verdict == Verdict::rejected) {
      return record(command.commandId, AckStatus::rejected, decision.reason);
    }
    if (actuator_ == nullptr) {
      return record(command.commandId, AckStatus::rejected, "door_unavailable");
    }
    if (!actuator_(command.action)) {
      return record(command.commandId, AckStatus::rejected, "door_busy");
    }
    return record(command.commandId, AckStatus::executed, nullptr);
  }

 private:
  const Ack* record(const char* commandId, AckStatus status, const char* reason) {
    history_.remember(commandId, status);
    ack_.commandId = commandId;
    ack_.status = statusName(status);
    ack_.reason = reason;
    return &ack_;
  }

  char localId_[65] = {0};
  Actuator actuator_ = nullptr;
  History history_;
  Ack ack_;
};

}  // namespace terminal_command
