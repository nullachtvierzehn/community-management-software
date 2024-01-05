import { Task } from 'graphile-worker'
import { camelCase, mapKeys } from 'lodash-es'

import { type SendEmailPayload } from './send_email.js'

interface RoomItemsSendNotificationsPayload {
  id: string
}

export const task: Task = async (inPayload, { addJob, query }) => {
  const payload: RoomItemsSendNotificationsPayload = inPayload as any
  const { id: roomItemId } = payload

  const { rows } = await query(
    `
      select 
        rs.room_id,
        r.title as room_title,
        rs.id as subscription_id,
        rs.subscriber_id,
        subscriber.username as subscriber_username,
        ri.contributor_id,
        contributor.username as contributor_username,
        ue.email as subscriber_email,
        ri.id as item_id,
        ri.type as item_type,
        app_hidden.tiptap_document_as_plain_text(ri.message_body) as message_body,  
        t.id as topic_id,
        t.slug as topic_slug,
        t.title as topic_title,
        t."content" as content_as_json,
        app_hidden.tiptap_document_as_plain_text(t."content") as content_as_plain_text,
        ri.contributed_at,
        rs.last_notification_at,
        coalesce(nullif(rs.notifications, 'default'), subscriber.default_handling_of_notifications) as notifications
      from app_public.room_items as ri 
      join app_public.rooms as r on (ri.room_id = r.id) 
      join app_public.room_subscriptions as rs on (
        ri.room_id = rs.room_id 
        and (rs.last_notification_at is null or ri.contributed_at > rs.last_notification_at)
      )
      join app_public.users as contributor on (ri.contributor_id = contributor.id)
      join app_public.users as subscriber on (rs.subscriber_id = subscriber.id)
      join app_public.user_emails as ue on (subscriber.id = ue.user_id and ue.is_primary)
      left join app_public.topics as t on (ri.topic_id = t.id)
      where
        ri.id = $1
        and subscriber.id <> contributor.id
        and ri.contributed_at is not null; 
    `,
    [roomItemId]
  )

  for (const row of rows) {
    await addJob('send_email', {
      options: {
        to: row.subscriber_email,
        subject: `Es gibt Neuigkeiten von ${row.contributer_username} in Raum ${row.room_title}`,
      },
      template: 'room_item_notification.mjml',
      variables: {
        ...mapKeys(row, (_v, k) => camelCase(k)),
        ...row,
        link: `${process.env.ROOT_URL}/rooms/${row.room_id}/items`,
      },
    } satisfies SendEmailPayload)

    await query(
      `
      update app_public.room_subscriptions set last_notification_at = current_timestamp where id = $1
    `,
      [row.subscription_id]
    )
  }
}

export default task
