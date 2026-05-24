type LVal {
  LNum(n: int),
  LSym(name: string),
  LStr(s: string),
  LBool(b: bool),
  LList(items: list<LVal>),
  LFun(params: list<string>, body: LVal, env: Env),
  LBuiltin(name: string),
  LNil
}