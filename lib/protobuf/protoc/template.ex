defmodule Protobuf.Protoc.Template do
  @moduledoc false
  @msg_tmpl Path.expand("./templates/message.ex.eex", :code.priv_dir(:protobuf))
  @enum_tmpl Path.expand("./templates/enum.ex.eex", :code.priv_dir(:protobuf))
  @svc_tmpl Path.expand("./templates/service.ex.eex", :code.priv_dir(:protobuf))
  @ext_tmpl Path.expand("./templates/extension.ex.eex", :code.priv_dir(:protobuf))

  require EEx

  EEx.function_from_file(
    :def,
    :message,
    @msg_tmpl,
    [
      :name,
      :full_name,
      :message_options,
      :options,
      :struct_fields,
      :typespec,
      :oneofs,
      :fields,
      :desc,
      :extensions,
      :custom_field_options_enabled
    ],
    trim: true
  )

  EEx.function_from_file(
    :def,
    :enum,
    @enum_tmpl,
    [:name, :options, :fields, :type, :desc, :enum_options],
    trim: true
  )

  EEx.function_from_file(:def, :service, @svc_tmpl, [:mod_name, :name, :methods, :desc],
    trim: true
  )

  EEx.function_from_file(:def, :extension, @ext_tmpl, [:name, :options, :extends], trim: true)
end
