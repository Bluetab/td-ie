#! /bin/bash

SCRIPT=$0
OPTION=$1
PROJECT_PATH=/home/ec2-user/data-lineage

main(){

  case "$OPTION" in
    (stop)
      stop
      exit 0
      ;;
    (start)
      start
      exit 0
      ;;
    (status)
      status
      exit 0
      ;;
    (restart)
      stop
      start
      exit 0
      ;;
    (*)
      echo "Usage: $SCRIPT {stop|start|restart|status}"
      exit 2
      ;;
  esac

}

stop(){
  stringStatus=`status`
  if [[ ! -z ${stringStatus} ]]; then
    exec kill -9 `ps aux | grep gunicorn | grep lineage | awk '{ print $2 }'`
  fi
}

start(){
  source /home/ec2-user/data-lineage/venv/bin/activate
  cd $PROJECT_PATH
  exec gunicorn --workers 3 --bind unix:/home/ec2-user/data-lineage/lineage.sock wsgi --daemon
}

status(){
  exec ps aux | grep gunicorn | grep lineage
}

main