web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
release: rake db:create && rake db:migrate && rake db:seed