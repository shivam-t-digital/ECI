PGDMP  6            	         |            postgres    15.3    16.1 J    #           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            $           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            %           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            &           1262    5    postgres    DATABASE     t   CREATE DATABASE postgres WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';
    DROP DATABASE postgres;
                postgres    false            '           0    0    DATABASE postgres    COMMENT     N   COMMENT ON DATABASE postgres IS 'default administrative connection database';
                   postgres    false    4390                        2615    2200    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
                pg_database_owner    false            (           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                   pg_database_owner    false    4            �            1255    16625    calculate_total_tokens(integer)    FUNCTION     k  CREATE FUNCTION public.calculate_total_tokens(user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_tokens INTEGER;
BEGIN
   SELECT COALESCE(SUM((m.tokens->>'total_tokens')::INTEGER), 0)
    INTO total_tokens
    FROM public.message m
    WHERE m.created_by = user_id;

    -- Return the total tokens
    RETURN total_tokens;
END;
$$;
 >   DROP FUNCTION public.calculate_total_tokens(user_id integer);
       public          postgres    false    4            �            1255    16627 9   calculate_total_tokens_by_project(integer, integer, text)    FUNCTION     �  CREATE FUNCTION public.calculate_total_tokens_by_project(project_id_param integer, total_tokens_param integer, total_tokens_key_param text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_tokens INT;
BEGIN
    -- Use the total_tokens_param parameter instead of extracting from JSON
    total_tokens := total_tokens_param;

    -- Access the desired key from the total_tokens_key_param parameter
    -- Replace 'your_numeric_key' with the actual key
    SELECT COALESCE(SUM(CAST(tokens->>total_tokens_key_param AS NUMERIC)), 0) INTO total_tokens
    FROM public.message m
    JOIN public.topic t ON m.topic_id = t.id
    WHERE t.project_id = project_id_param;

    RETURN total_tokens;
END;
$$;
 �   DROP FUNCTION public.calculate_total_tokens_by_project(project_id_param integer, total_tokens_param integer, total_tokens_key_param text);
       public          postgres    false    4            �            1255    16626 7   calculate_total_tokens_by_topic(integer, integer, text)    FUNCTION     �  CREATE FUNCTION public.calculate_total_tokens_by_topic(topic_id_param integer, total_tokens_param integer, total_tokens_key_param text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_tokens INT;
BEGIN
    -- Use the total_tokens_param parameter instead of extracting from JSON
    total_tokens := total_tokens_param;

    -- Access the desired key from the total_tokens_key_param parameter
    -- Replace 'your_numeric_key' with the actual key
    SELECT COALESCE(SUM(CAST(tokens->>total_tokens_key_param AS NUMERIC)), 0) INTO total_tokens
    FROM public.message
    WHERE topic_id = topic_id_param;

    RETURN total_tokens;
END;
$$;
 �   DROP FUNCTION public.calculate_total_tokens_by_topic(topic_id_param integer, total_tokens_param integer, total_tokens_key_param text);
       public          postgres    false    4            �            1255    16648 B   calculate_total_tokens_for_user_by_llm(integer, character varying)    FUNCTION     �	  CREATE FUNCTION public.calculate_total_tokens_for_user_by_llm(user_id_param integer, llm_name character varying) RETURNS TABLE(total_tokens integer, total_prompt_tokens integer, total_response_tokens integer, total_prompt_price numeric, total_response_price numeric, total_cost numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_tokens INTEGER;
    total_prompt_tokens INTEGER;
    total_response_tokens INTEGER;
    total_prompt_price DECIMAL(10, 5);
    total_response_price DECIMAL(10, 5);
    total_cost DECIMAL(10, 5);  -- New column for the total cost
    input_price DECIMAL(10, 5);
    output_price DECIMAL(10, 5);
BEGIN
    -- Initialize variables to 0
    total_tokens := 0;
    total_prompt_tokens := 0;
    total_response_tokens := 0;
    total_prompt_price := 0;
    total_response_price := 0;
    total_cost := 0;  -- Initialize total_cost to 0
    input_price := 0;
    output_price := 0;

    -- Retrieve input_price and output_price from the OpenAIPricing model
    SELECT op.input_price, op.output_price
    INTO input_price, output_price
    FROM openai_pricing op
    WHERE op.llm = llm_name;

    -- Debugging
    RAISE NOTICE 'input_price: %', input_price;
    RAISE NOTICE 'output_price: %', output_price;

    -- Sum of total_tokens, prompt_tokens, and response_tokens from messages with a specific LLM for a given user
    SELECT COALESCE(SUM(CAST(m.tokens->>'total_tokens' AS INTEGER)), 0),
           COALESCE(SUM(CAST(m.tokens->>'num_tokens_prompt' AS INTEGER)), 0),
           COALESCE(SUM(CAST(m.tokens->>'num_tokens_response' AS INTEGER)), 0)
    INTO total_tokens, total_prompt_tokens, total_response_tokens
    FROM public.message m
    JOIN public.topic t ON m.topic_id = t.id
    JOIN public.project p ON t.project_id = p.id
    WHERE p.user_id = user_id_param
        AND m."LLM" = llm_name;  -- Correct case for the column name

    -- Debugging
    RAISE NOTICE 'total_prompt_tokens: %', total_prompt_tokens;
    RAISE NOTICE 'total_response_tokens: %', total_response_tokens;

    -- Calculate prices for total prompt tokens and total response tokens based on the input and output prices
    total_prompt_price := total_prompt_tokens * input_price;
    total_response_price := total_response_tokens * output_price;

    -- Calculate the total cost
    total_cost := (total_prompt_price + total_response_price)/1000;

    RETURN QUERY SELECT total_tokens, total_prompt_tokens, total_response_tokens, total_prompt_price, total_response_price, total_cost;
END;
$$;
 p   DROP FUNCTION public.calculate_total_tokens_for_user_by_llm(user_id_param integer, llm_name character varying);
       public          postgres    false    4            �            1255    16624 7   get_total_tokens_sum_by_date(integer, integer, integer)    FUNCTION     �  CREATE FUNCTION public.get_total_tokens_sum_by_date(year_param integer DEFAULT NULL::integer, month_param integer DEFAULT NULL::integer, day_param integer DEFAULT NULL::integer) RETURNS TABLE(result_user_id integer, result_created_year integer, result_created_month numeric, result_created_day numeric, result_total_tokens_sum numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.created_by AS result_user_id,
        CAST(EXTRACT(YEAR FROM m.created_at) AS INT) AS result_created_year,
        EXTRACT(MONTH FROM m.created_at) AS result_created_month,
        EXTRACT(DAY FROM m.created_at) AS result_created_day,
        COALESCE(SUM(CAST(m.tokens ->> 'total_tokens' AS numeric)), 0) AS result_total_tokens_sum
    FROM
        public.message m
    WHERE
        (year_param IS NULL OR CAST(EXTRACT(YEAR FROM m.created_at) AS INT) = year_param)
        AND (month_param IS NULL OR EXTRACT(MONTH FROM m.created_at) = month_param)
        AND (day_param IS NULL OR EXTRACT(DAY FROM m.created_at) = day_param)
    GROUP BY
        m.created_by, result_created_year, result_created_month, result_created_day;

    -- Debug Information
    RAISE NOTICE 'Debug: Total Tokens Sum = %', result_total_tokens_sum;

    RETURN;
END;
$$;
 o   DROP FUNCTION public.get_total_tokens_sum_by_date(year_param integer, month_param integer, day_param integer);
       public          postgres    false    4            �            1255    16656 !   update_user_emails_to_lowercase()    FUNCTION     �   CREATE FUNCTION public.update_user_emails_to_lowercase() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE "user" SET email = LOWER(email);
END;
$$;
 8   DROP FUNCTION public.update_user_emails_to_lowercase();
       public          postgres    false    4            �            1259    16475    audit_event    TABLE     >  CREATE TABLE public.audit_event (
    id integer NOT NULL,
    user_id integer,
    event_type character varying(200),
    event_description character varying(1000),
    ip_address character varying(200),
    created_at timestamp with time zone DEFAULT now(),
    modified_at timestamp with time zone DEFAULT now()
);
    DROP TABLE public.audit_event;
       public         heap    postgres    false    4            �            1259    16474    audit_event_id_seq    SEQUENCE     �   CREATE SEQUENCE public.audit_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.audit_event_id_seq;
       public          postgres    false    219    4            )           0    0    audit_event_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.audit_event_id_seq OWNED BY public.audit_event.id;
          public          postgres    false    218            �            1259    16505    audit_trail    TABLE     3  CREATE TABLE public.audit_trail (
    id integer NOT NULL,
    event_id integer,
    action_type character varying(200),
    entity_type text,
    entity_id integer,
    event_description text,
    created_at timestamp with time zone DEFAULT now(),
    modified_at timestamp with time zone DEFAULT now()
);
    DROP TABLE public.audit_trail;
       public         heap    postgres    false    4            �            1259    16504    audit_trail_id_seq    SEQUENCE     �   CREATE SEQUENCE public.audit_trail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.audit_trail_id_seq;
       public          postgres    false    223    4            *           0    0    audit_trail_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.audit_trail_id_seq OWNED BY public.audit_trail.id;
          public          postgres    false    222            �            1259    16569    message    TABLE     �  CREATE TABLE public.message (
    id integer NOT NULL,
    topic_id integer,
    name character varying(200),
    "LLM" character varying(200),
    prompt text,
    response text,
    created_at timestamp with time zone DEFAULT now(),
    modified_at timestamp with time zone DEFAULT now(),
    created_by integer,
    modified_by integer,
    tokens json,
    is_deleted boolean DEFAULT false
);
    DROP TABLE public.message;
       public         heap    postgres    false    4            �            1259    16568    message_id_seq    SEQUENCE     �   CREATE SEQUENCE public.message_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.message_id_seq;
       public          postgres    false    229    4            +           0    0    message_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE public.message_id_seq OWNED BY public.message.id;
          public          postgres    false    228            �            1259    16642    openai_pricing    TABLE     �   CREATE TABLE public.openai_pricing (
    id integer NOT NULL,
    llm character varying(50) NOT NULL,
    version character varying(50) NOT NULL,
    input_price numeric(10,5) NOT NULL,
    output_price numeric(10,5) NOT NULL
);
 "   DROP TABLE public.openai_pricing;
       public         heap    postgres    false    4            �            1259    16641    openaipricing_id_seq    SEQUENCE     �   CREATE SEQUENCE public.openaipricing_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.openaipricing_id_seq;
       public          postgres    false    231    4            ,           0    0    openaipricing_id_seq    SEQUENCE OWNED BY     N   ALTER SEQUENCE public.openaipricing_id_seq OWNED BY public.openai_pricing.id;
          public          postgres    false    230            �            1259    16491    project    TABLE     �   CREATE TABLE public.project (
    id integer NOT NULL,
    user_id integer,
    name character varying(200),
    created_at timestamp with time zone DEFAULT now(),
    modified_at timestamp with time zone DEFAULT now()
);
    DROP TABLE public.project;
       public         heap    postgres    false    4            �            1259    16490    project_id_seq    SEQUENCE     �   CREATE SEQUENCE public.project_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.project_id_seq;
       public          postgres    false    221    4            -           0    0    project_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE public.project_id_seq OWNED BY public.project.id;
          public          postgres    false    220            �            1259    16535    project_sharing    TABLE     '  CREATE TABLE public.project_sharing (
    id integer NOT NULL,
    project_id integer,
    shared_by integer,
    shared_to integer,
    created_by integer,
    modified_by integer,
    created_at timestamp with time zone DEFAULT now(),
    modified_at timestamp with time zone DEFAULT now()
);
 #   DROP TABLE public.project_sharing;
       public         heap    postgres    false    4            �            1259    16534    project_sharing_id_seq    SEQUENCE     �   CREATE SEQUENCE public.project_sharing_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.project_sharing_id_seq;
       public          postgres    false    227    4            .           0    0    project_sharing_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.project_sharing_id_seq OWNED BY public.project_sharing.id;
          public          postgres    false    226            �            1259    16521    topic    TABLE       CREATE TABLE public.topic (
    id integer NOT NULL,
    project_id integer,
    name character varying(200),
    created_at timestamp with time zone DEFAULT now(),
    modified_at timestamp with time zone DEFAULT now(),
    created_by integer,
    modified_by integer
);
    DROP TABLE public.topic;
       public         heap    postgres    false    4            �            1259    16520    topic_id_seq    SEQUENCE     �   CREATE SEQUENCE public.topic_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.topic_id_seq;
       public          postgres    false    4    225            /           0    0    topic_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.topic_id_seq OWNED BY public.topic.id;
          public          postgres    false    224            �            1259    16446    user    TABLE     7  CREATE TABLE public."user" (
    id integer NOT NULL,
    name character varying(200),
    email character varying,
    active boolean,
    newsletter_opt_in boolean,
    created_at timestamp with time zone DEFAULT now(),
    modified_at timestamp with time zone DEFAULT now(),
    test text,
    image text
);
    DROP TABLE public."user";
       public         heap    postgres    false    4            �            1259    16445    user_id_seq    SEQUENCE     �   CREATE SEQUENCE public.user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 "   DROP SEQUENCE public.user_id_seq;
       public          postgres    false    215    4            0           0    0    user_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.user_id_seq OWNED BY public."user".id;
          public          postgres    false    214            �            1259    16459    user_preference    TABLE     I  CREATE TABLE public.user_preference (
    id integer NOT NULL,
    user_id integer,
    preference_type character varying(200),
    preference_selected character varying(200),
    description character varying(200),
    created_at timestamp with time zone DEFAULT now(),
    modified_at timestamp with time zone DEFAULT now()
);
 #   DROP TABLE public.user_preference;
       public         heap    postgres    false    4            �            1259    16458    user_preference_id_seq    SEQUENCE     �   CREATE SEQUENCE public.user_preference_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.user_preference_id_seq;
       public          postgres    false    4    217            1           0    0    user_preference_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.user_preference_id_seq OWNED BY public.user_preference.id;
          public          postgres    false    216            \           2604    16478    audit_event id    DEFAULT     p   ALTER TABLE ONLY public.audit_event ALTER COLUMN id SET DEFAULT nextval('public.audit_event_id_seq'::regclass);
 =   ALTER TABLE public.audit_event ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    219    218    219            b           2604    16508    audit_trail id    DEFAULT     p   ALTER TABLE ONLY public.audit_trail ALTER COLUMN id SET DEFAULT nextval('public.audit_trail_id_seq'::regclass);
 =   ALTER TABLE public.audit_trail ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    222    223    223            k           2604    16572 
   message id    DEFAULT     h   ALTER TABLE ONLY public.message ALTER COLUMN id SET DEFAULT nextval('public.message_id_seq'::regclass);
 9   ALTER TABLE public.message ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    229    228    229            o           2604    16645    openai_pricing id    DEFAULT     u   ALTER TABLE ONLY public.openai_pricing ALTER COLUMN id SET DEFAULT nextval('public.openaipricing_id_seq'::regclass);
 @   ALTER TABLE public.openai_pricing ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    231    230    231            _           2604    16494 
   project id    DEFAULT     h   ALTER TABLE ONLY public.project ALTER COLUMN id SET DEFAULT nextval('public.project_id_seq'::regclass);
 9   ALTER TABLE public.project ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    221    220    221            h           2604    16538    project_sharing id    DEFAULT     x   ALTER TABLE ONLY public.project_sharing ALTER COLUMN id SET DEFAULT nextval('public.project_sharing_id_seq'::regclass);
 A   ALTER TABLE public.project_sharing ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    226    227    227            e           2604    16524    topic id    DEFAULT     d   ALTER TABLE ONLY public.topic ALTER COLUMN id SET DEFAULT nextval('public.topic_id_seq'::regclass);
 7   ALTER TABLE public.topic ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    224    225    225            V           2604    16449    user id    DEFAULT     d   ALTER TABLE ONLY public."user" ALTER COLUMN id SET DEFAULT nextval('public.user_id_seq'::regclass);
 8   ALTER TABLE public."user" ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    215    214    215            Y           2604    16462    user_preference id    DEFAULT     x   ALTER TABLE ONLY public.user_preference ALTER COLUMN id SET DEFAULT nextval('public.user_preference_id_seq'::regclass);
 A   ALTER TABLE public.user_preference ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    217    216    217            w           2606    16484    audit_event audit_event_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.audit_event
    ADD CONSTRAINT audit_event_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.audit_event DROP CONSTRAINT audit_event_pkey;
       public            postgres    false    219            {           2606    16514    audit_trail audit_trail_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.audit_trail
    ADD CONSTRAINT audit_trail_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.audit_trail DROP CONSTRAINT audit_trail_pkey;
       public            postgres    false    223            �           2606    16578    message message_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.message DROP CONSTRAINT message_pkey;
       public            postgres    false    229            �           2606    16647 !   openai_pricing openaipricing_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY public.openai_pricing
    ADD CONSTRAINT openaipricing_pkey PRIMARY KEY (id);
 K   ALTER TABLE ONLY public.openai_pricing DROP CONSTRAINT openaipricing_pkey;
       public            postgres    false    231            y           2606    16498    project project_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.project DROP CONSTRAINT project_pkey;
       public            postgres    false    221                       2606    16542 $   project_sharing project_sharing_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.project_sharing
    ADD CONSTRAINT project_sharing_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.project_sharing DROP CONSTRAINT project_sharing_pkey;
       public            postgres    false    227            }           2606    16528    topic topic_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.topic
    ADD CONSTRAINT topic_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.topic DROP CONSTRAINT topic_pkey;
       public            postgres    false    225            q           2606    16457    user user_email_key 
   CONSTRAINT     Q   ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_email_key UNIQUE (email);
 ?   ALTER TABLE ONLY public."user" DROP CONSTRAINT user_email_key;
       public            postgres    false    215            s           2606    16455    user user_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public."user" DROP CONSTRAINT user_pkey;
       public            postgres    false    215            u           2606    16468 $   user_preference user_preference_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.user_preference
    ADD CONSTRAINT user_preference_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.user_preference DROP CONSTRAINT user_preference_pkey;
       public            postgres    false    217            �           2606    16485 $   audit_event audit_event_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.audit_event
    ADD CONSTRAINT audit_event_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(id);
 N   ALTER TABLE ONLY public.audit_event DROP CONSTRAINT audit_event_user_id_fkey;
       public          postgres    false    215    4211    219            �           2606    16515 %   audit_trail audit_trail_event_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.audit_trail
    ADD CONSTRAINT audit_trail_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.audit_event(id);
 O   ALTER TABLE ONLY public.audit_trail DROP CONSTRAINT audit_trail_event_id_fkey;
       public          postgres    false    223    219    4215            �           2606    16601    message message_created_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_created_by_fkey FOREIGN KEY (created_by) REFERENCES public."user"(id);
 I   ALTER TABLE ONLY public.message DROP CONSTRAINT message_created_by_fkey;
       public          postgres    false    4211    229    215            �           2606    16606     message message_modified_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_modified_by_fkey FOREIGN KEY (modified_by) REFERENCES public."user"(id);
 J   ALTER TABLE ONLY public.message DROP CONSTRAINT message_modified_by_fkey;
       public          postgres    false    4211    229    215            �           2606    16579    message message_topic_id_fkey    FK CONSTRAINT     }   ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES public.topic(id);
 G   ALTER TABLE ONLY public.message DROP CONSTRAINT message_topic_id_fkey;
       public          postgres    false    4221    225    229            �           2606    16558 /   project_sharing project_sharing_created_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.project_sharing
    ADD CONSTRAINT project_sharing_created_by_fkey FOREIGN KEY (created_by) REFERENCES public."user"(id);
 Y   ALTER TABLE ONLY public.project_sharing DROP CONSTRAINT project_sharing_created_by_fkey;
       public          postgres    false    4211    227    215            �           2606    16563 0   project_sharing project_sharing_modified_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.project_sharing
    ADD CONSTRAINT project_sharing_modified_by_fkey FOREIGN KEY (modified_by) REFERENCES public."user"(id);
 Z   ALTER TABLE ONLY public.project_sharing DROP CONSTRAINT project_sharing_modified_by_fkey;
       public          postgres    false    4211    227    215            �           2606    16543 /   project_sharing project_sharing_project_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.project_sharing
    ADD CONSTRAINT project_sharing_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project(id);
 Y   ALTER TABLE ONLY public.project_sharing DROP CONSTRAINT project_sharing_project_id_fkey;
       public          postgres    false    227    4217    221            �           2606    16548 .   project_sharing project_sharing_shared_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.project_sharing
    ADD CONSTRAINT project_sharing_shared_by_fkey FOREIGN KEY (shared_by) REFERENCES public."user"(id);
 X   ALTER TABLE ONLY public.project_sharing DROP CONSTRAINT project_sharing_shared_by_fkey;
       public          postgres    false    4211    227    215            �           2606    16553 .   project_sharing project_sharing_shared_to_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.project_sharing
    ADD CONSTRAINT project_sharing_shared_to_fkey FOREIGN KEY (shared_to) REFERENCES public."user"(id);
 X   ALTER TABLE ONLY public.project_sharing DROP CONSTRAINT project_sharing_shared_to_fkey;
       public          postgres    false    215    4211    227            �           2606    16499    project project_user_id_fkey    FK CONSTRAINT     |   ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(id);
 F   ALTER TABLE ONLY public.project DROP CONSTRAINT project_user_id_fkey;
       public          postgres    false    215    4211    221            �           2606    16611    topic topic_created_by_fkey    FK CONSTRAINT     ~   ALTER TABLE ONLY public.topic
    ADD CONSTRAINT topic_created_by_fkey FOREIGN KEY (created_by) REFERENCES public."user"(id);
 E   ALTER TABLE ONLY public.topic DROP CONSTRAINT topic_created_by_fkey;
       public          postgres    false    225    4211    215            �           2606    16616    topic topic_modified_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.topic
    ADD CONSTRAINT topic_modified_by_fkey FOREIGN KEY (modified_by) REFERENCES public."user"(id);
 F   ALTER TABLE ONLY public.topic DROP CONSTRAINT topic_modified_by_fkey;
       public          postgres    false    225    215    4211            �           2606    16529    topic topic_project_id_fkey    FK CONSTRAINT        ALTER TABLE ONLY public.topic
    ADD CONSTRAINT topic_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project(id);
 E   ALTER TABLE ONLY public.topic DROP CONSTRAINT topic_project_id_fkey;
       public          postgres    false    225    4217    221            �           2606    16469 ,   user_preference user_preference_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.user_preference
    ADD CONSTRAINT user_preference_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(id);
 V   ALTER TABLE ONLY public.user_preference DROP CONSTRAINT user_preference_user_id_fkey;
       public          postgres    false    215    4211    217           