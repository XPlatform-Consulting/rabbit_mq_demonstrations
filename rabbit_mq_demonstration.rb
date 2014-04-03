require 'carrot'

class RabbitMqDemonstration < ActiveRecord::Base
  include Action

 
  
  #revision history
  # => 0.0.1 first tracked version
  # => 0.0.2 renamed output - breaks compatibility with 0.0.1
  # => 0.1.0 adds support for vhost
  # => 0.2.0 adds ack vs no_ack configuration switch
  # => 0.2.1 adds help file
  # => 0.2.2 fix - edit.html file has a typo which make username and password fields default to 0
  def self.version
    #Needs a help file
    return 0, 2, 2
  end
  
  DEFAULT_POLLING_FREQUENCY = 5
  VAR_QUEUE_PORT = 'Queue_port'

  DEFAULT_QUEUE_HOST = nil
  DEFAULT_QUEUE_PASSWORD = nil
  DEFAULT_QUEUE_USER = nil
  DEFAULT_QUEUE_NODE = nil
  DEFAULT_QUEUE_PORT = nil
  
  
  OUT_MESSAGE = 'Message_payload'
  OUT_QUEUE = 'Queue_name'
  OUT_MESSAGES_LEFT = 'Messages_left_count'
  
  def outputs_spec
    return {OUT_MESSAGE=>TYPE_STRING, OUT_QUEUE=>TYPE_STRING, OUT_MESSAGES_LEFT=>TYPE_INT}.merge(formatted_outputs_get)
  end

  def inputs_spec
    optional_hash={}
    required_hash={}
    default_inputs_spec([:queue_name, :queue_user, :queue_password], required_hash, optional_hash)
    optional_hash[VAR_QUEUE_PORT] = TYPE_INT if (queue_port == nil)
    if (queue_host.blank? and queue_node.blank?)
      default_inputs_spec([:queue_node, :queue_host], required_hash, optional_hash) #makes both optional
    else
      if queue_node.blank?
        default_inputs_spec([:queue_node], required_hash, optional_hash)
      else
        default_inputs_spec([:queue_host], required_hash, optional_hash)
      end
    end
    return required_hash, optional_hash
  end

  def category
    return [CATEGORY_TRIGGERS]
  end
  
  def self.dependencies
    return [['carrot']]
  end
  
  def description
    return 'This action plug-in provides the ability to insert messages into an AMQP queue.'
  end

  def remote_execution?
    return false
  end

  def self.display_name
    return 'RabbitMQ'
  end

  
  def synchronous_execution?
    return  false
  end
  
  def multiple_execution?
    return (keep_ongoing  and (@isCanceled != true))
  end

  
  def timeout
    return 0
  end
  

  def execute
    return nil, "Initializing watch on queue #{queue_name_get}", nil
  end
  
  def check_status
    case
    when must_cancel?
      cancel
      return Action::STATUS_FAILED, 'Action Canceled', nil
    when must_pause?
      pause
      return nil ,'', polling_frequency_get
      #return Action::STATUS_PAUSED, "Action Paused",  tempo_get #0 instead would make the resume not dependent on probing frequency
    else
      resume
    end
    
    queue_params = {}
    queueHost = queue_host_get
    queue_params[:host] =  queueHost if (queueHost != nil)
    queue_params[:vhost] =  queue_vhost_get if (queue_vhost_get != nil)
    queue_params[:port] = queue_port_get if (queue_port_get != nil)
    queue_params[:user] = queue_user_get if (queue_user_get != nil)
    queue_params[:pass] = queue_password_get if (queue_password_get != nil)
    queue_params[:use_ssl] = use_ssl if (use_ssl != nil)
    queue_mgr = Carrot.new(queue_params)
    queue = queue_mgr.queue(queue_name_get, :durable=>true, :exchange=>queue_mgr.exchange)
    
    msg = queue.pop(:ack=>ack_get)
    if msg == nil
      queue_mgr.stop
      return nil, "Queue #{queue_name_get} is empty", polling_frequency_get
    else
      message_count = queue.message_count
      @outputs = {OUT_QUEUE=>queue_name_get, OUT_MESSAGES_LEFT=>message_count, OUT_MESSAGE=>msg}
      execMessage = post_process_message(msg)
      queue.ack
      queue_mgr.stop
      return STATUS_COMPLETE, "Retrieved '#{msg}' from  #{queue_name_get}, #{message_count} messages remaining"
    end
    
  end
  
  
  def post_process_message(msg)
    message = msg
    begin
      eval(message_postprocessing) unless message_postprocessing.blank?
    rescue Exception => e
      error "Could not post-process message '#{msg}': #{e.inspect}"
      debug_trace(e)
    end
    return message
  end
  
  
  #Pause the execution. returns false, if it could not be paused. True if it was successfully paused.
  def pause
    if @isPaused != true
      @status_details = "Paused at #{DateTime.now}"
      @isPaused = true
      report_progress(Action::STATUS_PAUSED,@status_details)
    end
    return true
  end
  
  #No actions required, the execution of the resume action is handled in the execute
  # upon notification that pausing is not requested anymore.
  def resume
    if @isPaused == true
      @status_details ="Resumed at #{DateTime.now}"
      @isPaused = false
      report_progress(Action::STATUS_INPROGRESS, @status_details)
    end
    return true
  end

  # Updates the status variables to reflect that a cancel request was made.
  # Does not have anything else to do as processing and aborting processing is
  #  handled in execute
  def cancel
    @isCanceled = true
    return true
  end
  
  
  def cancel_on_request?
    return true
  end

  def pause_on_request?
    return true
  end

  def resume_on_request?
    return true
  end

  def polling_frequency_get
    return (polling_frequency == nil) ? DEFAULT_POLLING_FREQUENCY : polling_frequency
  end
  
  
  def queue_host_get
    hostGet = default_get(:queue_host)
    if (hostGet.blank? and (queue_node_get.blank? == false))
      node = Node.identify(queue_node_get)
      hostGet = node.execution_address
    end
    return hostGet
  end
  
  def queue_node_get
    return default_get(:queue_node)
  end
  
  def queue_user_get
    return default_get(:queue_user)
  end
  
  def queue_password_get
    return default_get(:queue_password)
  end
  
  def queue_port_get
    return ((queue_port == nil) and (@inputs != nil)) ? @inputs[VAR_QUEUE_PORT] : queue_port
  end
  
  def queue_name_get
    return default_get(:queue_name)
  end

  def formatted_outputs_get
    return MultiType.convertValue_hash(formatted_outputs)
  end

  def queue_vhost_get
    return default_get(:vhost)
  end

  def ack_get
    return (no_ack != true)
  end
  
end
