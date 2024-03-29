{
  en => {
    labels => {
    #  super_user => 'Sup user',
    },
    attributes => {
      username => "User Name",
    },
    valiant => {
      models => {
        'example/schema/result_set/todo' => {
          one => 'Task',
          many => 'Tasks',
        },
        'example/schema/result/todo' => 'Task',
      },
      errors => {
        models => {
          'example/schema/result/profile' => {
            attributes => {
              registered => {
                bad_state => "Can't register is the state of {{state}}",
                'format/bad_state' => "{{message}}",
              },
            },
          },
        },
      },
      labels => {
        #'example/schema/result/role' => { admin => "God Role" },
      },
      attributes => {
        'example/model/schema/person' => {
          person_roles => "Roles",
        },
      }
    }
  },
};

