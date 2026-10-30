enum State { case idle, loaded }
func describe(_ state: State) -> String {
  switch state {
  case .idle: return "idle"
  }
}
