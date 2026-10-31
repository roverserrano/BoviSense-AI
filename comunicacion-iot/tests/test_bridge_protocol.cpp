#include "../esp32/bridge_hotspot_lora_discovery/bridge_protocol.h"
#include <cstdlib>
#include <iostream>
#include <string>

#define CHECK(condition) do { if (!(condition)) { std::cerr << "Fallo linea " << __LINE__ << ": " << #condition << '\n'; std::exit(1); } } while (0)
const std::string id(32, 'a'), other(32, 'b'), mac(32, 'c');
std::string command(char code = 'S') {
  return "C1|" + id + "|2000000060|" + code + "|" + ((code == 'H' || code == 'P') ? "-" : id) + "|" + mac;
}
std::string response(const std::string &session = id) {
  return "R1|" + id + "|" + session + "|STOPPED|27|2000000000|2000000000|" + mac;
}

int main(int argc, char **argv) {
  if (argc > 1 && std::string(argv[1]) == "--frames") {
    std::string line;
    while (std::getline(std::cin, line)) {
      const auto split = line.find('\t');
      CHECK(split != std::string::npos);
      bridge::Envelope cmd, reply;
      CHECK(bridge::commandEnvelope(line.substr(0, split).c_str(), cmd));
      CHECK(bridge::responseEnvelope(line.substr(split + 1).c_str(), reply));
      CHECK(std::string(cmd.request) == reply.request);
      CHECK(std::string(cmd.session) == reply.session);
    }
    std::cout << "contratos C1/R1 aceptados\n";
    return 0;
  }
  bridge::Envelope envelope;
  for (char code : std::string("HPSTQR")) CHECK(bridge::commandEnvelope(command(code).c_str(), envelope));
  CHECK(!bridge::commandEnvelope(command('X').c_str(), envelope));
  CHECK(!bridge::commandEnvelope((command() + "|extra").c_str(), envelope));
  CHECK(!bridge::commandEnvelope((" " + command()).c_str(), envelope));
  CHECK(!bridge::commandEnvelope((command() + "\n").c_str(), envelope));
  CHECK(!bridge::commandEnvelope(("C1|" + id + "|2000000060|H|" + id + "|" + mac).c_str(), envelope));
  CHECK(!bridge::commandEnvelope(("C1|" + id + "|2000000060|S|-|" + mac).c_str(), envelope));
  CHECK(bridge::responseEnvelope(response().c_str(), envelope));
  CHECK(!bridge::responseEnvelope((response() + "|extra").c_str(), envelope));
  CHECK(!bridge::responseEnvelope(("R1|" + id + "|" + id + "|UNKNOWN|-|2000000000|-|" + mac).c_str(), envelope));

  bridge::LineAssembler<bridge::COMMAND_LIMIT> parser;
  const auto framed = "~" + command() + "\n";
  unsigned complete = 0;
  // Cada byte puede llegar en una escritura BLE diferente.
  for (size_t i = 0; i < framed.size(); ++i) if (parser.feed(framed[i], static_cast<uint32_t>(i))) ++complete;
  CHECK(complete == 1);
  CHECK(parser.frame() == command());
  for (char c : std::string("~C1|incompleto")) parser.feed(c, 200);
  CHECK(!parser.feed('\n', 6000));
  for (char c : "~basura") parser.feed(c, 6001);
  for (char c : framed) if (parser.feed(c, 6002)) ++complete;
  CHECK(complete == 2);
  parser.feed('~', 6003);
  for (unsigned i = 0; i < 181; ++i) parser.feed('x', 6003);
  CHECK(!parser.feed('\n', 6003));
  parser.feed('~', 6004);
  parser.feed(static_cast<char>(0x80), 6004);
  CHECK(!parser.feed('\n', 6004));
  for (char c : framed.substr(0, 20)) parser.feed(c, 6005);
  parser.reset();  // Desconexion: el sufijo de otra conexion no completa nada.
  CHECK(!parser.feed('\n', 6005));

  bridge::Transaction transaction;
  CHECK(bridge::commandEnvelope(command().c_str(), envelope));
  transaction.start(command().c_str(), envelope, 1000, 7);
  transaction.sent(1000);
  CHECK(!transaction.retryDue(6999));
  CHECK(transaction.retryDue(7000));
  transaction.sent(7000);
  CHECK(transaction.retryDue(13000));
  transaction.sent(13000);
  CHECK(!transaction.retryDue(19000));
  CHECK(!transaction.expired(22999));
  CHECK(transaction.expired(23000));
  CHECK(transaction.sameCommand(command().c_str()));
  CHECK(std::string(transaction.command) == command());
  CHECK(bridge::responseEnvelope(response().c_str(), envelope));
  CHECK(transaction.matches(envelope));
  transaction.received = true;
  CHECK(transaction.matches(envelope));  // La segunda R1 sigue siendo reenviable.
  CHECK(!transaction.retryDue(20000));
  CHECK(bridge::responseEnvelope(response(other).c_str(), envelope));
  CHECK(!transaction.matches(envelope));
  transaction.reset();
  CHECK(!transaction.matches(envelope));

  CHECK(bridge::elapsed(15, UINT32_MAX - 10, 25));
  CHECK(!bridge::elapsed(13, UINT32_MAX - 10, 25));
  CHECK(bridge::commandEnvelope(command().c_str(), envelope));
  transaction.start(command().c_str(), envelope, UINT32_MAX - 100, 8);
  transaction.sent(UINT32_MAX - 100);
  CHECK(transaction.retryDue(6000));
  CHECK(!transaction.expired(6000));
  CHECK(transaction.expired(22000));
  std::cout << "OK: formato, fragmentos, limites, reconexion, correlacion, reintentos y rollover\n";
}
