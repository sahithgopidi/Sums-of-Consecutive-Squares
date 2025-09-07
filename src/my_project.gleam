import argv
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor

type BossMsg {
  Result(List(Int))
}

type WorkerMsg {
  Compute(low: Int, high: Int, k: Int, reply_to: process.Subject(BossMsg))
}

fn worker_handler(_state: Nil, msg: WorkerMsg) -> actor.Next(Nil, WorkerMsg) {
  case msg {
    Compute(l, h, kk, rep) -> {
      let found =
        list.range(l, h)
        |> list.filter(fn(m) {
          let s = sum_of_squares(m, kk)
          is_perfect_square(s)
        })
      process.send(rep, Result(found))
      actor.stop()
    }
  }
}

fn start_worker() -> Result(
  actor.Started(process.Subject(WorkerMsg)),
  actor.StartError,
) {
  actor.new(Nil)
  |> actor.on_message(worker_handler)
  |> actor.start
}

type BossState {
  BossState(
    results: List(List(Int)),
    pending: Int,
    output_subject: process.Subject(List(Int)),
  )
}

fn sum_of_squares(m: Int, k: Int) -> Int {
  let mk2 = k * m * m
  let sum_i = k * { k - 1 } / 2
  let tm = 2 * m * sum_i
  let sum_i2 = k * { k - 1 } * { 2 * k - 1 } / 6
  mk2 + tm + sum_i2
}

fn search_sqrt(low: Int, high: Int, n: Int) -> Int {
  case high - low <= 1 {
    True -> {
      case high * high <= n {
        True -> high
        False -> low
      }
    }
    False -> {
      let mid = low + { high - low } / 2
      let mid_sq = mid * mid
      case mid_sq == n {
        True -> mid
        False ->
          case mid_sq < n {
            True -> search_sqrt(mid + 1, high, n)
            False -> search_sqrt(low, mid - 1, n)
          }
      }
    }
  }
}

fn integer_square_root(n: Int) -> Int {
  case n < 2 {
    True -> n
    False -> search_sqrt(1, n / 2 + 1, n)
  }
}

fn is_perfect_square(n: Int) -> Bool {
  case n < 0 {
    True -> False
    False -> {
      let r = integer_square_root(n)
      r * r == n
    }
  }
}

fn boss_handler(
  state: BossState,
  msg: BossMsg,
) -> actor.Next(BossState, BossMsg) {
  case msg {
    Result(found) -> {
      let new_results = [found, ..state.results]
      let new_pending = state.pending - 1
      case new_pending == 0 {
        True -> {
          let all_found =
            list.flatten(new_results)
            |> list.sort(by: int.compare)
          process.send(state.output_subject, all_found)
          actor.stop()
        }
        False -> {
          actor.continue(BossState(
            results: new_results,
            pending: new_pending,
            output_subject: state.output_subject,
          ))
        }
      }
    }
  }
}

pub fn main() {
  let args = argv.load().arguments
  case args {
    [n_str, k_str] -> {
      let n_res = int.parse(n_str)
      let k_res = int.parse(k_str)
      case n_res, k_res {
        Ok(n), Ok(k) if k > 0 && n >= k -> {
          let output_subject = process.new_subject()

          // Simple fallback - use 16 workers instead of trying to get system info
          let num_workers = 4

          let max_start = n
          let chunk_size = { max_start + num_workers - 1 } / num_workers
          let ranges =
            list.range(0, num_workers - 1)
            |> list.map(fn(i) {
              let low = i * chunk_size + 1
              let high = int.min(low + chunk_size - 1, max_start)
              case low <= high {
                True -> Some(#(low, high))
                False -> None
              }
            })
            |> list.filter_map(fn(opt) { option.to_result(opt, Nil) })
          let num_assigned = list.length(ranges)

          // Create boss first
          let boss_builder =
            actor.new(BossState([], num_assigned, output_subject))
            |> actor.on_message(boss_handler)
          let boss_res = actor.start(boss_builder)

          case boss_res {
            Ok(boss_started) -> {
              let boss_subject = boss_started.data

              // Now start workers and send them the boss subject
              list.each(ranges, fn(range) {
                let worker_res = start_worker()
                case worker_res {
                  Ok(started) -> {
                    let worker_subject = started.data
                    process.send(
                      worker_subject,
                      Compute(range.0, range.1, k, boss_subject),
                    )
                  }
                  Error(_) -> Nil
                }
              })

              let timeout = 100_000_000
              case process.receive(output_subject, timeout) {
                Ok(lst) -> {
                  case lst {
                    [] -> io.println("No valid solutions found")
                    _ -> list.each(lst, fn(m) { io.println(int.to_string(m)) })
                  }
                }
                Error(_) -> io.println("Timeout")
              }
            }
            Error(_) -> io.println("Error starting boss actor")
          }
        }
        _, _ -> io.println("Invalid N or k")
      }
    }
    _ -> io.println("Usage: lukas N k")
  }
}
