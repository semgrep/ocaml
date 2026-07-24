(* TEST
 native;
*)

(* Interrupt N domains, each stuck in a NON-ALLOCATING loop, from another
   domain, and confirm each raises. This is the case that allocation-driven
   mechanisms (Gc.alarm, memprof) cannot reach. No timing/sleep is needed: the
   pending bitmask and young_limit latch, so the interrupt is delivered at the
   target's next safe point even if fired before it reaches the loop. *)

let timeout_bit = 1

let n = 4

let () =
  let caught = Array.init n (fun _ -> Atomic.make false) in
  let idx = Array.init n (fun _ -> Atomic.make (-1)) in
  let domains =
    Array.init n (fun i ->
      Domain.spawn (fun () ->
        Domain.set_interrupt_handler (fun reasons ->
          if reasons land timeout_bit <> 0 then raise Exit);
        try
          Atomic.set idx.(i) (Domain.self_index ());
          let x = ref 0 in
          while true do incr x done;
          ignore !x
        with Exit -> Atomic.set caught.(i) true))
  in
  Array.iter (fun a -> while Atomic.get a < 0 do Domain.cpu_relax () done) idx;
  Array.iter (fun a -> Domain.interrupt ~index:(Atomic.get a) ~reasons:timeout_bit)
    idx;
  Array.iter Domain.join domains;
  Array.iteri (fun i a -> Printf.printf "domain %d caught=%b\n" i (Atomic.get a))
    caught;
  assert (Array.for_all Atomic.get caught);
  print_endline "OK: all non-allocating domains were interrupted"
