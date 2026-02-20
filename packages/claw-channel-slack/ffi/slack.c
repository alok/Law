#include <stdint.h>

uint32_t claw_slack_start(uint32_t seed) {
  return seed + 1;
}

uint32_t claw_slack_send_count(uint64_t text_len) {
  (void)text_len;
  return 0;
}

uint32_t claw_slack_stop(uint32_t handle) {
  (void)handle;
  return 0;
}
