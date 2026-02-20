#include <stdint.h>

uint32_t claw_telegram_start(uint32_t seed) {
  return seed + 1;
}

uint32_t claw_telegram_send_count(uint64_t text_len) {
  (void)text_len;
  return 0;
}

uint32_t claw_telegram_stop(uint32_t handle) {
  (void)handle;
  return 0;
}
