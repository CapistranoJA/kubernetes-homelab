#!/bin/sh

for ip in 10.9.8.{50..53}; do
  ssh-keygen -R "$ip"
done