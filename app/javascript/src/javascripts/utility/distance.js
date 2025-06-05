
class LevenshteinOperation {
  static SymMap = Object.freeze({
    deletion: "-",
    insertion: "+",
    substitution: "%",
    none: "=",
  });
  constructor(operation, weight, prior_distance, token) {
    this.operation = operation;
    this.weight = weight;
    this.prior_distance = prior_distance;
    this.token = token;

    this.symbol = "";
    if (SymMap.hasOwnProperty(this.operation)) {
      this.symbol = SymMap[ this.operation.toString() ];
    } else {
      if (!(operation instanceof Array)) {
        operation = operation.toString().split(" ");
      }
      if (operation.some(e => SymMap.hasOwnProperty(e))) {
        for (const e of operation) {
          if (SymMap.hasOwnProperty(this.operation)) {
            this.symbol += SymMap[ this.operation.toString() ];
          } else { }
        }
      }
    }
  }
  toString() {
    return `${this.symbol}${this.operation}${this.symbol}`;
  }
}
// *********************** Class syntax
class LDistance {
  /**
   * @type {Readonly<Map<String, Number>>}
   * TODO: Convert
   */
  static OPERATION_WEIGHTS = Object.freeze({
    deletion: 1,
    insertion: 1,
    substitution: 1,
    none: 0,
  });

  static MAX_WEIGHT = Object.values(LDistance.OPERATION_WEIGHTS).reduce((acc, e) => e > acc ? e : acc);

  /**
   * Levenshtein distance
   * @param {Array} source_arr 
   * @param {Array} dest_arr 
   * @param {boolean} normalize 
   * @returns {Number} A number representing the number of weighted steps needed to be taken to go
   * from `source_arr` to `dest_arr` (lower score == more similar); if normalized, 0 means inputs are
   * considered identical, 1 means they are as different as can be.
   */
  static l_distance(source_arr, dest_arr, normalize = true) {
    let num_rows = source_arr.length;
    let num_cols = dest_arr.length;
    let max_weight = normalize ? (num_rows > num_cols ? num_rows : num_cols) * LDistance.MAX_WEIGHT : 1;
    num_rows++;
    num_cols++;
    // A 2d array sized 1 larger than each input
    let d = [ "", ...source_arr ].map((_) => [ "", ...dest_arr ].map((__) => 0));
    // Debug
    // let d_substring = [ "", ...source_arr ].map((_) => [ "", ...dest_arr ].map((__) => ""));

    for (let i = 1; i < num_rows; i++) {
      d[ i ][ 0 ] = i * LDistance.OPERATION_WEIGHTS[ "deletion" ];
      // Debug
      // d_substring[ i ][ 0 ] = source_arr[ i - 1 ];
    }

    for (let j = 1; j < num_cols; j++) {
      d[ 0 ][ j ] = j * LDistance.OPERATION_WEIGHTS[ "insertion" ];
      // Debug
      // d_substring[ 0 ][ j ] = dest_arr[ j - 1 ];
    }

    for (let j = 1; j < num_cols; j++) {
      for (let i = 1; i < num_rows; i++) {
        let substitution_cost = source_arr[ i - 1 ] == dest_arr[ j - 1 ] ? LDistance.OPERATION_WEIGHTS[ "none" ] : LDistance.OPERATION_WEIGHTS[ "substitution" ];

        d[ i ][ j ] = Math.min(
          d[ i - 1 ][ j ] + LDistance.OPERATION_WEIGHTS[ "deletion" ],
          d[ i ][ j - 1 ] + LDistance.OPERATION_WEIGHTS[ "insertion" ],
          d[ i - 1 ][ j - 1 ] + substitution_cost,
        )
        // Debug
        /* let deletion_output = d[ i - 1 ][ j ] + LDistance.OPERATION_WEIGHTS[ "deletion" ];
        let insertion_output = d[ i ][ j - 1 ] + LDistance.OPERATION_WEIGHTS[ "insertion" ];
        let substitution_output = d[ i - 1 ][ j - 1 ] + substitution_cost;
        if (substitution_output == deletion_output) {
          if (insertion_output == deletion_output) { // substitution == deletion == insertion
            d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j - 1 ]} ?${d_substring[ 0 ][ j ]}?`;
          } else if (deletion_output < insertion_output) { // (substitution == deletion) < insertion
            d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j ]} -%${d_substring[ 0 ][ j ]}%-`;
          } else { // insertion < (deletion == substitution)
            d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +${d_substring[ 0 ][ j ]}+`;
          }
        } else if (substitution_output < deletion_output) {
          if (substitution_output < insertion_output) { // substitution < |insertion deletion|
            if (substitution_output == 0) {
              d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j - 1 ]} =${d_substring[ i ][ 0 ]}=`;
            } else {
              d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j - 1 ]} %${d_substring[ 0 ][ j ]}%`;
            }
          } else if (substitution_output == insertion_output) { // (insertion == substitution) < deletion
            d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +%${d_substring[ 0 ][ j ]}%+`;
          } else { // insertion < substitution < deletion
            d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +${d_substring[ 0 ][ j ]}+`;
          }
        } else if (deletion_output < substitution_output) {
          if (deletion_output < insertion_output) { // deletion < |insertion substitution|
            d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j ]} -${d_substring[ i ][ 0 ]}-`;
          } else if (deletion_output == insertion_output) { // (insertion == deletion) < substitution
            d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j ]} +-${d_substring[ i ][ 0 ]}-+`;
          } else { // insertion < deletion < substitution
            d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +${d_substring[ 0 ][ j ]}+`;
          }
        }  */
      }
    }
    // Debug
    // console.table(d);
    // console.table(d_substring);
    return d[ num_rows - 1 ][ num_cols - 1 ] / max_weight;
  }
  static assert_equal(expected, actual, msg = "") {
    if (expected == actual) return;
    throw new Error(`${msg}\nExpected: ${expected}\nActual: ${actual}`);
  }
  static test_l_distance() {
    function assert_equal(expected, actual, msg = "") {
      if (expected == actual) return;
      throw new Error(`${msg}\nExpected: ${expected}\nActual: ${actual}`);
    }
    // should "correctly determine the relative differences of tag arrays" do
    let s = [ "a", "specific", "list", "of", "tags", "to", "search", "for" ];
    let d1_1 = [ "specific", "list", "of", "tags", "to", "search", "for" ];
    let d1_2 = [ "a", "specific", "listing", "of", "tags", "to", "search", "for" ];
    let d1_3 = [ "a", "specific", "list", "of", "tags", "to", "search", "for", "now" ];
    let d2 = [ "specific", "listing", "of", "tags", "to", "search", "for" ];
    let d3 = [ "specific", "listing", "of", "tags", "to", "search", "for", "now" ];
    let d_f = [ "and", "now", "for", "something", "completely", "different" ];
    assert_equal(0, LDistance.l_distance(s, s, false));
    assert_equal(LDistance.OPERATION_WEIGHTS[ "deletion" ], LDistance.l_distance(s, d1_1, false));
    assert_equal(LDistance.OPERATION_WEIGHTS[ "substitution" ], LDistance.l_distance(s, d1_2, false));
    assert_equal(LDistance.OPERATION_WEIGHTS[ "insertion" ], LDistance.l_distance(s, d1_3, false));
    assert_equal(2, LDistance.l_distance(s, d2, false));
    assert_equal(3, LDistance.l_distance(s, d3, false));
    assert_equal(0, LDistance.l_distance(s, s, true));
    assert_equal(1, LDistance.l_distance(s, d_f, true));
    // end
  }
};
export default LDistance;
// *********************** Object syntax
// let LDistance = {};
// LDistance = {
//   OPERATION_WEIGHTS: Object.freeze({
//     deletion: 1,
//     insertion: 1,
//     substitution: 1,
//     none: 0,
//   }),

//   MAX_WEIGHT: Object.values(LDistance.OPERATION_WEIGHTS).reduce((acc, e) => e > acc ? e : acc),

//   /**
//    * Levenshtein distance
//    * @param {Array} source_arr 
//    * @param {Array} dest_arr 
//    * @param {boolean} normalize 
//    * @returns {Number} A number representing the number of weighted steps needed to be taken to go
//    * from `source_arr` to `dest_arr` (lower score == more similar); if normalized, 0 means inputs are
//    * considered identical, 1 means they are as different as can be.
//    */
//   l_distance(source_arr, dest_arr, normalize = true) {
//     let num_rows = source_arr.length;
//     let num_cols = dest_arr.length;
//     let max_weight = normalize ? (num_rows > num_cols ? num_rows : num_cols) * LDistance.MAX_WEIGHT : 1;
//     num_rows++;
//     num_cols++;
//     // A 2d array sized 1 larger than each input
//     let d = [ "", ...source_arr ].map((_) => [ "", ...dest_arr ].map((__) => 0));
//     let d_substring = [ "", ...source_arr ].map((_) => [ "", ...dest_arr ].map((__) => ""));

//     for (let i = 1; i < num_rows; i++) {
//       d[ i ][ 0 ] = i * LDistance.OPERATION_WEIGHTS[ "deletion" ];
//       d_substring[ i ][ 0 ] = source_arr[ i - 1 ];
//     }

//     for (let j = 1; j < num_cols; j++) {
//       d[ 0 ][ j ] = j * LDistance.OPERATION_WEIGHTS[ "insertion" ];
//       d_substring[ 0 ][ j ] = dest_arr[ j - 1 ];
//     }
//     // (1..num_cols).each { |j| d_substring[0][j] = dest_arr[j - 1] }

//     for (let j = 1; j < num_cols; j++) {
//       for (let i = 1; i < num_rows; i++) {
//         let substitution_cost = source_arr[ i - 1 ] == dest_arr[ j - 1 ] ? LDistance.OPERATION_WEIGHTS[ "none" ] : LDistance.OPERATION_WEIGHTS[ "substitution" ];
//         let deletion_output = d[ i - 1 ][ j ] + LDistance.OPERATION_WEIGHTS[ "deletion" ];
//         let insertion_output = d[ i ][ j - 1 ] + LDistance.OPERATION_WEIGHTS[ "insertion" ];
//         let substitution_output = d[ i - 1 ][ j - 1 ] + substitution_cost;

//         if (substitution_output == deletion_output) {
//           if (insertion_output == deletion_output) { // (substitution == deletion == insertion
//             d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j - 1 ]} ?${d_substring[ 0 ][ j ]}?`;
//           } else if (deletion_output < insertion_output) { // (substitution == deletion) < insertion
//             d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j ]} -%${d_substring[ 0 ][ j ]}%-`;
//           } else { // insertion < (deletion == substitution)
//             d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +${d_substring[ 0 ][ j ]}+`;
//           }
//         } else if (substitution_output < deletion_output) {
//           if (substitution_output < insertion_output) { // substitution < |insertion deletion|
//             if (substitution_output == 0) {
//               d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j - 1 ]} =${d_substring[ i ][ 0 ]}=`;
//             } else {
//               d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j - 1 ]} %${d_substring[ 0 ][ j ]}%`;
//             }
//           } else if (substitution_output == insertion_output) { // (insertion == substitution) < deletion
//             d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +%${d_substring[ 0 ][ j ]}%+`;
//           } else { // insertion < substitution < deletion
//             d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +${d_substring[ 0 ][ j ]}+`;
//           }
//         } else if (deletion_output < substitution_output) {
//           if (deletion_output < insertion_output) { // deletion < |insertion substitution|
//             d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j ]} -${d_substring[ i ][ 0 ]}-`;
//           } else if (deletion_output == insertion_output) { // (insertion == deletion) < substitution
//             d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j ]} +-${d_substring[ i ][ 0 ]}-+`;
//           } else { // insertion < deletion < substitution
//             d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +${d_substring[ 0 ][ j ]}+`;
//           }
//         }

//         d[ i ][ j ] = Math.min(
//           d[ i - 1 ][ j ] + LDistance.OPERATION_WEIGHTS[ "deletion" ],
//           d[ i ][ j - 1 ] + LDistance.OPERATION_WEIGHTS[ "insertion" ],
//           d[ i - 1 ][ j - 1 ] + substitution_cost,
//         )
//       }
//     }
//     console.table(d);
//     console.table(d_substring);
//     // d.each { |e| puts "#{e}" }
//     // max_tag_length = dest_arr.inject(source_arr.inject(0) { |acc, e| [e.length, acc].max }) { |acc, e| [e.length, acc].max }
//     // d_substring.each { |e| puts "#{e.map { |e1| Kernel.sprintf("%#{max_tag_length}s", e1) }}" }
//     return d[ num_rows - 1 ][ num_cols - 1 ] / max_weight;
//   },
//   assert_equal(expected, actual, msg = "") {
//     if (expected == actual) return;
//     throw new Error(`${msg}\nExpected: ${expected}\nActual: ${actual}`);
//   },
//   test_l_distance() {
//     // should "correctly determine the relative differences of tag arrays" do
//     let s = [ "a", "specific", "list", "of", "tags", "to", "search", "for" ];
//     let d1_1 = [ "specific", "list", "of", "tags", "to", "search", "for" ];
//     let d1_2 = [ "a", "specific", "listing", "of", "tags", "to", "search", "for" ];
//     let d1_3 = [ "a", "specific", "list", "of", "tags", "to", "search", "for", "now" ];
//     let d2 = [ "specific", "listing", "of", "tags", "to", "search", "for" ];
//     let d3 = [ "specific", "listing", "of", "tags", "to", "search", "for", "now" ];
//     let d_f = [ "and", "now", "for", "something", "completely", "different" ];
//     assert_equal(0, LDistance.l_distance(s, s, false));
//     assert_equal(LDistance.OPERATION_WEIGHTS[ "deletion" ], LDistance.l_distance(s, d1_1, false));
//     assert_equal(LDistance.OPERATION_WEIGHTS[ "substitution" ], LDistance.l_distance(s, d1_2, false));
//     assert_equal(LDistance.OPERATION_WEIGHTS[ "insertion" ], LDistance.l_distance(s, d1_3, false));
//     assert_equal(2, LDistance.l_distance(s, d2, false));
//     assert_equal(3, LDistance.l_distance(s, d3, false));
//     assert_equal(0, LDistance.l_distance(s, s, true));
//     assert_equal(1, LDistance.l_distance(s, d_f, true));
//     // end
//   },
// };
// export default Object.freeze(LDistance);

// *********************** Manually constructed
// let LDistance = {}
// LDistance.OPERATION_WEIGHTS = Object.freeze({
//   deletion: 1,
//   insertion: 1,
//   substitution: 1,
//   none: 0,
// });

// LDistance.MAX_WEIGHT = Object.values(LDistance.OPERATION_WEIGHTS).reduce((acc, e) => e > acc ? e : acc);

// /**
//  * Levenshtein distance
//  * @param {Array} source_arr 
//  * @param {Array} dest_arr 
//  * @param {boolean} normalize 
//  * @returns {Number} A number representing the number of weighted steps needed to be taken to go
//  * from `source_arr` to `dest_arr` (lower score == more similar); if normalized, 0 means inputs are
//  * considered identical, 1 means they are as different as can be.
//  */
// LDistance.l_distance = function (source_arr, dest_arr, normalize = true) {
//   let num_rows = source_arr.length;
//   let num_cols = dest_arr.length;
//   let max_weight = normalize ? (num_rows > num_cols ? num_rows : num_cols) * LDistance.MAX_WEIGHT : 1;
//   num_rows++;
//   num_cols++;
//   // A 2d array sized 1 larger than each input
//   let d = [ "", ...source_arr ].map((_) => [ "", ...dest_arr ].map((__) => 0));
//   let d_substring = [ "", ...source_arr ].map((_) => [ "", ...dest_arr ].map((__) => ""));

//   for (let i = 1; i < num_rows; i++) {
//     d[ i ][ 0 ] = i * LDistance.OPERATION_WEIGHTS[ "deletion" ];
//     d_substring[ i ][ 0 ] = source_arr[ i - 1 ];
//   }

//   for (let j = 1; j < num_cols; j++) {
//     d[ 0 ][ j ] = j * LDistance.OPERATION_WEIGHTS[ "insertion" ];
//     d_substring[ 0 ][ j ] = dest_arr[ j - 1 ];
//   }
//   // (1..num_cols).each { |j| d_substring[0][j] = dest_arr[j - 1] }

//   for (let j = 1; j < num_cols; j++) {
//     for (let i = 1; i < num_rows; i++) {
//       let substitution_cost = source_arr[ i - 1 ] == dest_arr[ j - 1 ] ? LDistance.OPERATION_WEIGHTS[ "none" ] : LDistance.OPERATION_WEIGHTS[ "substitution" ];
//       let deletion_output = d[ i - 1 ][ j ] + LDistance.OPERATION_WEIGHTS[ "deletion" ];
//       let insertion_output = d[ i ][ j - 1 ] + LDistance.OPERATION_WEIGHTS[ "insertion" ];
//       let substitution_output = d[ i - 1 ][ j - 1 ] + substitution_cost;

//       if (substitution_output == deletion_output) {
//         if (insertion_output == deletion_output) { // (substitution == deletion == insertion
//           d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j - 1 ]} ?${d_substring[ 0 ][ j ]}?`;
//         } else if (deletion_output < insertion_output) { // (substitution == deletion) < insertion
//           d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j ]} -%${d_substring[ 0 ][ j ]}%-`;
//         } else { // insertion < (deletion == substitution)
//           d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +${d_substring[ 0 ][ j ]}+`;
//         }
//       } else if (substitution_output < deletion_output) {
//         if (substitution_output < insertion_output) { // substitution < |insertion deletion|
//           if (substitution_output == 0) {
//             d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j - 1 ]} =${d_substring[ i ][ 0 ]}=`;
//           } else {
//             d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j - 1 ]} %${d_substring[ 0 ][ j ]}%`;
//           }
//         } else if (substitution_output == insertion_output) { // (insertion == substitution) < deletion
//           d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +%${d_substring[ 0 ][ j ]}%+`;
//         } else { // insertion < substitution < deletion
//           d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +${d_substring[ 0 ][ j ]}+`;
//         }
//       } else if (deletion_output < substitution_output) {
//         if (deletion_output < insertion_output) { // deletion < |insertion substitution|
//           d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j ]} -${d_substring[ i ][ 0 ]}-`;
//         } else if (deletion_output == insertion_output) { // (insertion == deletion) < substitution
//           d_substring[ i ][ j ] = `${d_substring[ i - 1 ][ j ]} +-${d_substring[ i ][ 0 ]}-+`;
//         } else { // insertion < deletion < substitution
//           d_substring[ i ][ j ] = `${d_substring[ i ][ j - 1 ]} +${d_substring[ 0 ][ j ]}+`;
//         }
//       }

//       d[ i ][ j ] = Math.min(
//         d[ i - 1 ][ j ] + LDistance.OPERATION_WEIGHTS[ "deletion" ],
//         d[ i ][ j - 1 ] + LDistance.OPERATION_WEIGHTS[ "insertion" ],
//         d[ i - 1 ][ j - 1 ] + substitution_cost,
//       )
//     }
//   }
//   console.table(d);
//   console.table(d_substring);
//   // d.each { |e| puts "#{e}" }
//   // max_tag_length = dest_arr.inject(source_arr.inject(0) { |acc, e| [e.length, acc].max }) { |acc, e| [e.length, acc].max }
//   // d_substring.each { |e| puts "#{e.map { |e1| Kernel.sprintf("%#{max_tag_length}s", e1) }}" }
//   return d[ num_rows - 1 ][ num_cols - 1 ] / max_weight;
// };
// function assert_equal(expected, actual, msg = "") {
//   if (expected == actual) return;
//   throw new Error(`${msg}\nExpected: ${expected}\nActual: ${actual}`);
// }
// LDistance.test_l_distance = function () {
//   // should "correctly determine the relative differences of tag arrays" do
//   let s = [ "a", "specific", "list", "of", "tags", "to", "search", "for" ];
//   let d1_1 = [ "specific", "list", "of", "tags", "to", "search", "for" ];
//   let d1_2 = [ "a", "specific", "listing", "of", "tags", "to", "search", "for" ];
//   let d1_3 = [ "a", "specific", "list", "of", "tags", "to", "search", "for", "now" ];
//   let d2 = [ "specific", "listing", "of", "tags", "to", "search", "for" ];
//   let d3 = [ "specific", "listing", "of", "tags", "to", "search", "for", "now" ];
//   let d_f = [ "and", "now", "for", "something", "completely", "different" ];
//   assert_equal(0, LDistance.l_distance(s, s, false));
//   assert_equal(LDistance.OPERATION_WEIGHTS[ "deletion" ], LDistance.l_distance(s, d1_1, false));
//   assert_equal(LDistance.OPERATION_WEIGHTS[ "substitution" ], LDistance.l_distance(s, d1_2, false));
//   assert_equal(LDistance.OPERATION_WEIGHTS[ "insertion" ], LDistance.l_distance(s, d1_3, false));
//   assert_equal(2, LDistance.l_distance(s, d2, false));
//   assert_equal(3, LDistance.l_distance(s, d3, false));
//   assert_equal(0, LDistance.l_distance(s, s, true));
//   assert_equal(1, LDistance.l_distance(s, d_f, true));
//   // end
// };
