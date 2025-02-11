sleep_instantiate :: proc(name_prefix: string, name: string, owner : ^zd.Eh) -> ^zd.Eh {
  SleepInfo *info = new (SleepInfo);//[odin] info := new (SleepInfo)
  info->counter = 0;//[odin] info.counter = 0
  ... //[odin]    name_with_id := gensym("?")
  ... //[odin]    fmt.eprintf ("sleep_instantiate &info=%p info=%v\n", info, info)
  return zd.make_leaf (..., ..., ..., info, &sleep_handler)  //[odin] return zd.make_leaf (name_prefix, name_with_id, owner, info, sleep_handler)
}

//[odin] sleep_handler :: proc(eh: ^Eh, message: ^Message) {
//[odin]     fmt.eprintf ("sleep_handler eh=%v eh.instance_data=%p\n", eh, eh.instance_data)
  SleepInfo* info = (((void*)[2])(eh->instance_data))[0]//[odin]     info := eh.instance_data.(SleepInfo)
//[odin]     if ! zd.is_tick (message) {
  info->save_message = message;//[odin] 	info.saved_message = message
//[odin]     }
  int count = info->counter;//[odin]     count := info.counter
  count += 1;//[odin]     count += 1
//[odin]     if count > SLEEPDELAY {
//[odin] 	send(eh=eh, port="output", datum=message.datum, causingMessage=nil)
    count = 0;//[odin] 	count = 0
//[odin]     }
  info->counter = count;//[odin]     info.counter = count
//[odin] }
//[odin] 
