(* TEST
 include unix;
 native;
*)

(* A domain with a pending Domain.interrupt must still be able to enter a
   blocking section. caml_enter_blocking_section's loop exits only once
   young_limit is no longer armed, and the only thing it drains inside the loop
   is pending *signals* -- never caml_do_pending_actions_res, which is what
   clears an interrupt. So re-arming young_limit for a pending interrupt makes
   that loop unable to ever terminate. *)

let timeout_bit = 1
let iters = 200

let () =
  let hits = Atomic.make 0 in
  let idx = Atomic.make (-1) in
  let worker =
    Domain.spawn (fun () ->
      Domain.set_interrupt_handler (fun _ -> Atomic.incr hits);
      Atomic.set idx (Domain.self_index ());
      for _ = 1 to iters do Unix.sleepf 0.001 done)
  in
  while Atomic.get idx < 0 do Domain.cpu_relax () done;
  let target = Atomic.get idx in
  let stop = Atomic.make false in
  let hammer =
    Domain.spawn (fun () ->
      while not (Atomic.get stop) do
        Domain.interrupt ~index:target ~reasons:timeout_bit
      done)
  in
  Domain.join worker;
  Atomic.set stop true;
  Domain.join hammer;
  print_endline "OK: blocking sections make progress with interrupts pending"
