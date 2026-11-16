import {requireChatGPTUser} from '../chatgpt-auth';
import ConfigureClient from './client';
export const dynamic='force-dynamic';
export default async function Configure(){await requireChatGPTUser('/configure');return <ConfigureClient/>;}
