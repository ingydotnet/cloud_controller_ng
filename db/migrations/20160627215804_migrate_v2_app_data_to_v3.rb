Sequel.migration do
  up do
    ####
    ##  App usage events
    ####
    generate_stop_events_query = <<-SQL
        INSERT INTO app_usage_events
          (guid, created_at, instance_count, memory_in_mb_per_instance, state, app_guid, app_name, space_guid, space_name, org_guid, buildpack_guid, buildpack_name, package_state, parent_app_name, parent_app_guid, process_type, task_guid, task_name, package_guid, previous_state, previous_package_state, previous_memory_in_mb_per_instance, previous_instance_count)
        SELECT %s, now(), p.instances, p.memory, 'STOPPED', p.guid, p.name, s.guid, s.name, o.guid, d.buildpack_receipt_buildpack_guid, COALESCE(d.buildpack_receipt_buildpack, l.buildpack), p.package_state, a.name, a.guid, p.type, NULL, NULL, pkg.guid, 'STARTED', p.package_state, p.memory, p.instances
          FROM apps as p
            INNER JOIN apps_v3 as a ON (a.guid=p.app_guid)
            INNER JOIN spaces as s ON (s.guid=a.space_guid)
            INNER JOIN organizations as o ON (o.id=s.organization_id)
            INNER JOIN packages as pkg ON (a.guid=pkg.app_guid)
            INNER JOIN v3_droplets as d ON (a.guid=d.app_guid)
            INNER JOIN buildpack_lifecycle_data as l ON (d.guid=l.droplet_guid)
          WHERE p.state='STARTED'
    SQL
    if self.class.name.match(/mysql/i)
      run generate_stop_events_query % 'UUID()'
    elsif self.class.name.match(/postgres/i)
      run generate_stop_events_query % 'get_uuid()'
    end

    ###
    ##  V3 data removal
    ###
    alter_table(:packages) do
      drop_foreign_key [:app_guid]
    end
    alter_table(:apps) do
      drop_foreign_key [:app_guid]
      drop_index :app_guid
      drop_foreign_key [:space_id]
      drop_foreign_key [:stack_id], name: :fk_apps_stack_id
      drop_index [:name, :space_id], name: :apps_space_id_name_nd_idx
    end
    alter_table(:route_mappings) do
      drop_foreign_key [:app_guid]
    end
    alter_table(:v3_service_bindings) do
      drop_foreign_key [:app_id]
    end
    drop_table(:tasks)
    drop_table(:package_docker_data)
    drop_table(:v3_droplets)

    run 'DELETE FROM apps_routes WHERE app_id IN (SELECT id FROM apps WHERE app_guid IS NOT NULL);'
    run 'DELETE FROM apps WHERE app_guid IS NOT NULL OR deleted_at IS NOT NULL;'
    self[:route_mappings].truncate
    self[:packages].truncate
    self[:buildpack_lifecycle_data].truncate
    self[:v3_service_bindings].truncate
    self[:apps_v3].truncate

    rename_table :apps, :processes
    rename_table :apps_v3, :apps

    alter_table(:processes) do
      add_index :app_guid
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_processes_app_guid
    end
    alter_table(:packages) do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_packages_app_guid
    end
    alter_table(:route_mappings) do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_route_mappings_app_guid
    end
    alter_table(:v3_service_bindings) do
      add_foreign_key [:app_id], :apps, key: :id, name: :fk_v3_service_bindings_app_id   # this is by id instead of guid
    end

    create_table :v3_droplets do
      VCAP::Migration.common(self)

      String :state, null: false
      index :state, name: :droplets_state_index
      String :droplet_hash
      String :process_types, type: :text
      String :execution_metadata, type: :text
      String :error_id
      String :error_description, type: :text
      String :encrypted_environment_variables, text: true
      String :salt
      Integer :staging_memory_in_mb
      Integer :staging_disk_in_mb

      String :buildpack_receipt_stack_name
      String :buildpack_receipt_buildpack
      String :buildpack_receipt_buildpack_guid
      String :docker_receipt_image

      String :package_guid
      index :package_guid, name: :package_guid_index

      String :app_guid
      foreign_key [:app_guid], :apps, key: :guid, name: :fk_droplets_app_guid

      if self.class.name.match /mysql/i
        table_name = tables.find { |t| t =~ /v3_droplets/ }
        run "ALTER TABLE `#{table_name}` CONVERT TO CHARACTER SET utf8;"
      end
    end

    create_table :tasks do
      VCAP::Migration.common(self)

      String :name, case_insensitive: true, null: false
      index :name, name: :tasks_name_index
      String :command, null: false, text: true
      String :state, null: false
      index :state, name: :tasks_state_index
      Integer :memory_in_mb, null: true
      String :encrypted_environment_variables, text: true, null: true
      String :salt, null: true
      String :failure_reason, null: true, size: 4096

      String :app_guid, null: false
      foreign_key [:app_guid], :apps, key: :guid, name: :fk_tasks_app_guid

      String :droplet_guid, null: false
      foreign_key [:droplet_guid], :v3_droplets, key: :guid, name: :fk_tasks_droplet_guid

      if self.class.name.match /mysql/i
        table_name = tables.find { |t| t =~ /tasks/ }
        run "ALTER TABLE `#{table_name}` CONVERT TO CHARACTER SET utf8;"
      end
    end

    ####
    ## Backfill apps table
    ###
    run <<-SQL
        INSERT INTO apps (guid, name, salt, encrypted_environment_variables, created_at, updated_at, space_guid)
        SELECT p.guid, p.name, p.salt, p.encrypted_environment_json, p.created_at, p.updated_at, s.guid
        FROM processes as p, spaces as s
        WHERE p.space_id = s.id
        ORDER BY p.id
    SQL

    run <<-SQL
        UPDATE processes SET app_guid=guid
    SQL

    #####
    ## App Lifecycle
    ####
    alter_table(:buildpack_lifecycle_data) do
      drop_index(:guid)
      set_column_allow_null(:guid)
    end

    run <<-SQL
        INSERT INTO buildpack_lifecycle_data (app_guid, stack)
        SELECT processes.guid, stacks.name
        FROM processes, stacks
        WHERE docker_image is NULL AND stacks.id = processes.stack_id
    SQL

    run <<-SQL
        UPDATE buildpack_lifecycle_data
        SET buildpack=(
          SELECT buildpacks.name
          FROM buildpacks
            JOIN processes ON processes.admin_buildpack_id = buildpacks.id
          WHERE processes.admin_buildpack_id IS NOT NULL AND processes.guid=buildpack_lifecycle_data.app_guid
        )
    SQL

    run <<-SQL
        UPDATE buildpack_lifecycle_data
        SET buildpack=(
          SELECT processes.buildpack
          FROM processes
          WHERE processes.admin_buildpack_id IS NULL AND processes.guid=buildpack_lifecycle_data.app_guid
        )
        WHERE buildpack IS NULL
    SQL

    if self.class.name.match(/mysql/i)
      run 'update buildpack_lifecycle_data set guid=UUID();'
    elsif self.class.name.match(/postgres/i)
      run 'update buildpack_lifecycle_data set guid=get_uuid();'
    end

    alter_table(:buildpack_lifecycle_data) do
      set_column_not_null :guid
      add_index :guid, unique: true, name: :buildpack_lifecycle_data_guid_index
    end

    #####
    ## Backfill packages
    ####
    alter_table(:packages) do
      drop_column :url
      add_column :docker_image, String, type: :text
    end

    run <<-SQL
      INSERT INTO packages (guid, type, package_hash, state, error, app_guid)
      SELECT guid, 'bits', package_hash, 'READY', NULL, guid
        FROM processes
      WHERE package_hash IS NOT NULL AND docker_image IS NULL
    SQL

    run <<-SQL
      INSERT INTO packages (guid, type, state, error, app_guid, docker_image)
      SELECT  guid, 'docker', 'READY', NULL, guid, docker_image
        FROM processes
      WHERE docker_image IS NOT NULL
    SQL

    alter_table(:processes) do
      drop_column :name
      drop_column :encrypted_environment_json
      drop_column :salt
      drop_column :buildpack
      drop_column :space_id
      drop_column :stack_id
      drop_column :admin_buildpack_id
      drop_column :docker_image
      drop_column :package_hash
      drop_column :package_state
      drop_column :droplet_hash
      drop_column :package_pending_since
      drop_column :deleted_at
      drop_column :staging_task_id
      drop_column :detected_buildpack_guid
      drop_column :detected_buildpack_name
      drop_column :staging_failed_reason
      drop_column :staging_failed_description
    end
  end
end