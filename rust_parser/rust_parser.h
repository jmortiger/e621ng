#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef enum TokenType {
  None,
  Tag,
  Metatag,
  GroupOpen,
  GroupClose,
  Group = 8,
  Root = 16,
} TokenType;

typedef enum Prefix {
  PrefixNone,
  Negated,
  Optional,
} Prefix;

typedef struct GenericTokenNodeFinal {
  /**
   * Index in query where the token's first character is.
   */
  uint32_t starting_index;
  uint32_t length;
  enum TokenType token_type;
  enum Prefix prefix;
  uint32_t token_index;
  struct GenericTokenNodeFinal *sub_tokens;
  uintptr_t len;
} GenericTokenNodeFinal;

struct GenericTokenNodeFinal *tokenize_ffi(const char *query,
                                                uintptr_t depth,
                                                uintptr_t remaining_tokens,
                                                bool error_on_token_count_exceeded,
                                                bool error_on_depth_exceeded,
                                                bool preserve_unclosed_group_tokens);

char *check_token(struct GenericTokenNodeFinal *v, const char *query);

void free_token_string(char *s);
