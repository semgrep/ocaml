(* TEST
 native;
*)

(* Domain slots are recycled. A fresh domain must inherit neither the previous
   occupant's pending reasons nor its handler: before these were cleared, an
   interrupt aimed at a slot whose domain had already exited was delivered to
   its successor and ran the dead domain's closure, crashing the runtime. *)

let timeout_bit = 1

let () =
  let d1 =
    Domain.spawn (fun () ->
      Domain.set_interrupt_handler (fun _ -> raise Exit);
      Domain.self_index ())
  in
  let slot = Domain.join d1 in
  (* aimed at a slot whose domain has already gone *)
  Domain.interrupt ~index:slot ~reasons:timeout_bit;
  let inherited = Atomic.make false in
  let d2 =
    Domain.spawn (fun () ->
      try
        let x = ref 0 in
        for _ = 1 to 20_000_000 do x := (!x + 1) land 0xffff done;
        ignore !x
      with Exit -> Atomic.set inherited true)
  in
  Domain.join d2;
  assert (not (Atomic.get inherited));
  print_endline "OK: recycled slot did not inherit interrupt state"
