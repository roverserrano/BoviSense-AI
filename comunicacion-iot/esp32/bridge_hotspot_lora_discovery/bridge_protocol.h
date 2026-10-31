#pragma once

// Contrato de transporte, sin Arduino ni claves. La autenticacion sigue en
// backend/Jetson. Se prueba tambien en el host sin encender ninguna radio.
#include <stdint.h>
#include <stddef.h>
#include <string.h>

namespace bridge {
constexpr size_t COMMAND_LIMIT = 180;
constexpr size_t RESPONSE_LIMIT = 200;
constexpr size_t BLE_CHUNK = 18;  // Compatible con ATT MTU minimo (23).
constexpr uint32_t ASSEMBLY_TIMEOUT_MS = 5000;
constexpr uint32_t RESPONSE_TIMEOUT_MS = 22000;
constexpr uint32_t TX_TIMEOUT_MS = 3000;
constexpr uint32_t RETRY_INTERVAL_MS = 6000;
constexpr uint8_t MAX_ATTEMPTS = 3;

inline bool elapsed(uint32_t now, uint32_t since, uint32_t interval) {
  return static_cast<uint32_t>(now - since) >= interval;
}

inline bool hexId(const char *text) {
  if (strlen(text) != 32) return false;
  for (size_t i = 0; i < 32; ++i) {
    if (!((text[i] >= '0' && text[i] <= '9') || (text[i] >= 'a' && text[i] <= 'f'))) return false;
  }
  return true;
}

inline bool decimal(const char *text, size_t limit) {
  const size_t length = strlen(text);
  if (length == 0 || length > limit) return false;
  for (size_t i = 0; i < length; ++i) if (text[i] < '0' || text[i] > '9') return false;
  return true;
}

inline bool split(char *text, char **fields, size_t expected) {
  size_t count = 1;
  fields[0] = text;
  for (char *p = text; *p; ++p) {
    if (*p < 32 || *p > 126) return false;
    if (*p == '|') {
      if (count >= expected) return false;
      *p = '\0';
      fields[count++] = p + 1;
    }
  }
  return count == expected;
}

struct Envelope {
  char request[33] = {};
  char session[33] = {};
};

inline bool commandEnvelope(const char *text, Envelope &out) {
  if (strlen(text) > COMMAND_LIMIT) return false;
  char copy[COMMAND_LIMIT + 1];
  strcpy(copy, text);
  char *fields[6];
  if (!split(copy, fields, 6) || strcmp(fields[0], "C1") != 0 ||
      !hexId(fields[1]) || !decimal(fields[2], 11) || !hexId(fields[5])) return false;
  if (strlen(fields[3]) != 1 || strchr("HPSTQR", fields[3][0]) == nullptr) return false;
  const bool global = fields[3][0] == 'H' || fields[3][0] == 'P';
  if (global ? strcmp(fields[4], "-") != 0 : !hexId(fields[4])) return false;
  strcpy(out.request, fields[1]);
  strcpy(out.session, fields[4]);
  return true;
}

inline bool responseEnvelope(const char *text, Envelope &out) {
  if (strlen(text) > RESPONSE_LIMIT) return false;
  char copy[RESPONSE_LIMIT + 1];
  strcpy(copy, text);
  char *fields[8];
  if (!split(copy, fields, 8) || strcmp(fields[0], "R1") != 0 ||
      !hexId(fields[1]) || !hexId(fields[7]) ||
      (strcmp(fields[2], "-") != 0 && !hexId(fields[2])) ||
      !decimal(fields[5], 11) ||
      (strcmp(fields[4], "-") != 0 && !decimal(fields[4], 7)) ||
      (strcmp(fields[6], "-") != 0 && !decimal(fields[6], 11))) return false;
  const char *states[] = {"READY", "STARTED", "RUNNING", "STOPPED", "RESULT", "ERROR", "BUSY", "IDLE"};
  bool known = false;
  for (const char *state : states) if (strcmp(fields[3], state) == 0) known = true;
  if (!known) return false;
  strcpy(out.request, fields[1]);
  strcpy(out.session, fields[2]);
  return true;
}

template <size_t Limit> class LineAssembler {
 public:
  void reset() { length_ = 0; receiving_ = false; }
  bool feed(char value, uint32_t now) {
    if (elapsed(now, lastByte_, ASSEMBLY_TIMEOUT_MS)) reset();
    lastByte_ = now;
    if (value == '~') {
      receiving_ = true;
      length_ = 0;
    } else if (receiving_ && value == '\n') {
      buffer_[length_] = '\0';
      reset();
      return true;
    } else if (receiving_ && value >= 32 && value <= 126 && length_ < Limit) {
      buffer_[length_++] = value;
    } else {
      reset();
    }
    return false;
  }
  const char *frame() const { return buffer_; }

 private:
  char buffer_[Limit + 1] = {};
  size_t length_ = 0;
  uint32_t lastByte_ = 0;
  bool receiving_ = false;
};

class Transaction {
 public:
  void start(const char *frame, const Envelope &envelope, uint32_t now, uint32_t generation) {
    strcpy(command, frame);
    ids = envelope;
    epoch = generation;
    startedAt = now;
    sentAt = now;
    attempts = 0;
    received = false;
    active = true;
  }
  void reset() { active = false; received = false; attempts = 0; }
  void sent(uint32_t now) { sentAt = now; ++attempts; }
  bool expired(uint32_t now) const { return active && elapsed(now, startedAt, RESPONSE_TIMEOUT_MS); }
  bool retryDue(uint32_t now) const {
    return active && !received && !expired(now) && attempts < MAX_ATTEMPTS &&
           elapsed(now, sentAt, RETRY_INTERVAL_MS);
  }
  bool matches(const Envelope &response) const {
    return active && strcmp(response.request, ids.request) == 0 && strcmp(response.session, ids.session) == 0;
  }
  bool sameCommand(const char *frame) const { return active && strcmp(command, frame) == 0; }

  char command[COMMAND_LIMIT + 1] = {};
  Envelope ids;
  uint32_t epoch = 0;
  uint32_t startedAt = 0;
  uint32_t sentAt = 0;
  uint8_t attempts = 0;
  bool received = false;
  bool active = false;
};
}  // namespace bridge
