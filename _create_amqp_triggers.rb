class RabbitMqDemonstrations < ActiveRecord::Migration
  def self.up
    create_table :action_rabbit_mq_demonstrations do |t|
      t.string   :name
      t.text :comments
      t.boolean :keep_ongoing
      t.integer :polling_frequency
      t.string :queue_name
      t.string :queue_host
      t.string :queue_node
      t.integer :queue_port
      t.string  :queue_user
      t.string  :queue_password
      t.boolean :use_ssl
      t.text   :message_postprocessing
      t.text :formatted_outputs
      t.boolean :no_ack
      t.string :queue_vhost
      t.timestamps
    end
  end

  def self.down
    drop_table :action_rabbit_mq_demonstrations
  end
end
