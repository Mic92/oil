from typing import List

def receive(fd: int, fd_out: List[int]) -> str: ...
def send(fd: int, msg: str): ...
