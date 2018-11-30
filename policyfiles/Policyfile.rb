name 'my_a2'
run_list 'recipe[my_a2::default]'
cookbook 'my_a2', path: '..'
cookbook 'managed-automate2', path: '../../managed-automate2-cookbook'
default_source :supermarket
