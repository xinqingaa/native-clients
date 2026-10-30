final class Box { var value = 0 }
func reader(_ box: Box) -> @Sendable () -> Int { { box.value } }
